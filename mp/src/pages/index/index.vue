<template>
  <view class="page page-shell" :class="step === 'login' ? 'login-page' : ''">
    <view v-if="booting" class="boot">
      <view class="logo-wrap">
        <image class="logo" src="/static/logo.png" mode="aspectFit" />
      </view>
      <text class="boot-t">派客邦</text>
    </view>

    <template v-else-if="step === 'home'">
      <view class="brand-block">
        <view class="logo-wrap">
          <image class="logo" src="/static/splash_logo.png" mode="aspectFit" />
        </view>
        <text class="brand">派客邦</text>
        <text class="title">本地商家与上门师傅的作业工具</text>
        <text class="sub">给已入驻商家和所属师傅使用。这一页不用登录，真实订单在登录后查看。</text>
      </view>

      <text class="section-title">谁可以使用</text>
      <view class="who surface">
        <view class="badge">商</view>
        <view class="who-body">
          <text class="who-t">商家</text>
          <text class="who-d">接单、办理、派单，以及管理本店师傅。需先入驻，并通过运营审核。</text>
        </view>
      </view>
      <view class="who surface">
        <view class="badge tech">师</view>
        <view class="who-body">
          <text class="who-t">上门师傅</text>
          <text class="who-d">查看上门任务，拍照确认交付。无法完成时退回商家。由所属商家添加，不单独注册。</text>
        </view>
      </view>

      <text class="section-title">办理怎么走</text>
      <view class="card surface">
        <view v-for="(item, i) in steps" :key="item.title" class="step">
          <view class="step-rail">
            <text class="step-no">{{ i + 1 }}</text>
            <view v-if="i < steps.length - 1" class="step-line" />
          </view>
          <view class="step-body">
            <text class="step-t">{{ item.title }}</text>
            <text class="step-d">{{ item.desc }}</text>
          </view>
        </view>
      </view>

      <text class="section-title">订单示例</text>
      <text class="section-note">虚构示例，姓名和电话已打码。</text>
      <view class="sample surface">
        <view class="sample-top">
          <text class="biz">融合宽带</text>
          <text class="pill">示例</text>
        </view>
        <text class="sample-name">300M 融合套餐</text>
        <text class="sample-meta">张* · 138****1206</text>
        <text class="sample-meta">某市某区示例路 8 号</text>
        <text class="sample-no">DEMO20261021001</text>
        <text class="sample-tip">商家登录后可接单。需要上门时，再派给本店师傅。</text>
      </view>
      <text class="privacy">客户姓名、手机号和地址只对已登录的对应商家或师傅展示。</text>

      <view class="dock">
        <view class="dock-row">
          <view class="dock-btn primary" @click="chooseRole('merchant')">商家登录</view>
          <view class="dock-btn tech" @click="chooseRole('technician')">师傅登录</view>
        </view>
        <text class="apply-link" @click="goApply">商家入驻申请</text>
      </view>
    </template>

    <view v-else class="wrap login-page">
      <view class="brand-block compact">
        <view class="back" @click="backHome">
          <text class="back-arrow">‹</text>
          <text class="back-text">返回</text>
        </view>
        <view class="logo-wrap sm">
          <image class="logo" src="/static/logo.png" mode="aspectFit" />
        </view>
        <text class="title">{{ role === 'merchant' ? '商家登录' : '师傅登录' }}</text>
        <text class="sub">{{
          role === 'merchant' ? '使用已通过审核的手机号登录' : '使用商家为您开通的手机号登录'
        }}</text>
      </view>

      <view class="form surface">
        <view class="field">
          <text class="label">手机号</text>
          <input
            class="input"
            type="number"
            maxlength="11"
            v-model="phone"
            placeholder="请输入手机号"
            placeholder-class="ph"
          />
        </view>
        <view class="field code-field">
          <text class="label">验证码</text>
          <input
            class="input code-input"
            type="number"
            maxlength="6"
            v-model="code"
            placeholder="请输入验证码"
            placeholder-class="ph"
          />
          <view class="code-btn" :class="{ off: countdown > 0 }" @click="sendCode">
            {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
          </view>
        </view>

        <button class="login-btn btn-primary" :disabled="loading" @click="onLogin">登录</button>
        <text v-if="role === 'merchant'" class="apply-link mid" @click="goApply">还没有门店？申请入驻</text>
      </view>
    </view>

    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShow, onUnload } from '@dcloudio/uni-app'
import type { Role } from '@/types/order'
import AppFeedback from '@/components/AppFeedback.vue'
import { showToast } from '@/store/feedback'
import { getSession, goRoleHome, loginByPhone } from '@/store/session'
import { request } from '@/api/http'

const steps = [
  { title: '商家提交入驻', desc: '填写门店、服务地区和可接业务，等待运营审核。' },
  { title: '审核通过后登录', desc: '使用申请手机号登录，处理新录入的订单。' },
  { title: '办理或派单上门', desc: '能线上办结的直接办结；需要上门的派给本店师傅。' },
  { title: '师傅上门确认', desc: '师傅拍照交付。无法完成则退回，由商家继续跟进或重新派单。' },
]

const booting = ref(true)
const step = ref<'home' | 'login'>('home')
const role = ref<Role>('merchant')
const phone = ref('')
const code = ref('')
const loading = ref(false)
const countdown = ref(0)
let timer: ReturnType<typeof setInterval> | null = null
let navTimer: ReturnType<typeof setTimeout> | null = null
let redirecting = false

function resumeIfLoggedIn() {
  const s = getSession()
  if (!s) {
    booting.value = false
    redirecting = false
    return false
  }
  if (redirecting) return true
  redirecting = true
  booting.value = true
  goRoleHome(s.role)
  return true
}

function setNavTitle(title: string) {
  uni.setNavigationBarTitle({ title })
}

onLoad((query) => {
  if (resumeIfLoggedIn()) return
  const roleQuery = query?.role
  if (roleQuery === 'merchant' || roleQuery === 'technician') {
    chooseRole(roleQuery)
  }
})

onShow(() => {
  resumeIfLoggedIn()
})

onUnload(() => {
  if (timer) clearInterval(timer)
  if (navTimer) clearTimeout(navTimer)
})

function chooseRole(r: Role) {
  role.value = r
  phone.value = ''
  code.value = ''
  step.value = 'login'
  setNavTitle(r === 'merchant' ? '商家登录' : '师傅登录')
}

function backHome() {
  step.value = 'home'
  setNavTitle('派客邦')
}

function goApply() {
  uni.navigateTo({ url: '/pages/merchant/apply' })
}

async function sendCode() {
  if (!/^1\d{10}$/.test(phone.value.trim())) {
    showToast('请先填写正确手机号', { type: 'error' })
    return
  }
  if (countdown.value > 0) return
  try {
    await request({ url: '/api/mp/auth/sms', method: 'POST', data: { phone: phone.value.trim() } })
  } catch (err) {
    showToast(err instanceof Error ? err.message : '验证码发送失败', { type: 'error' })
    return
  }
  showToast('验证码已发送', { type: 'success', subtitle: '请查收短信' })
  countdown.value = 60
  timer = setInterval(() => {
    countdown.value -= 1
    if (countdown.value <= 0 && timer) {
      clearInterval(timer)
      timer = null
    }
  }, 1000)
}

async function onLogin() {
  const p = phone.value.trim()
  const c = code.value.trim()
  if (!/^1\d{10}$/.test(p)) {
    showToast('请输入正确的手机号', { type: 'error' })
    return
  }
  if (!/^\d{4,6}$/.test(c)) {
    showToast('请输入验证码', { type: 'error' })
    return
  }

  loading.value = true
  const err = await loginByPhone(p, role.value, c)
  loading.value = false
  if (err) {
    showToast(err, { type: 'error' })
    return
  }
  const s = getSession()
  if (!s) return
  showToast('登录成功', {
    type: 'success',
    subtitle: s.role === 'merchant' ? `欢迎回来，${s.displayName}` : `你好，${s.displayName}`,
    duration: 900,
  })
  if (navTimer) clearTimeout(navTimer)
  navTimer = setTimeout(() => goRoleHome(s.role), 900)
}
</script>

<style scoped>
.page {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  overflow-x: hidden;
}
.login-page {
  padding-top: 56rpx;
}
.boot {
  min-height: 70vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
.boot-t {
  margin-top: 8rpx;
  font-size: 32rpx;
  font-weight: 700;
  color: #0d2b4d;
  letter-spacing: 2rpx;
}
.wrap {
  padding-bottom: 40rpx;
}
.brand-block {
  margin-bottom: 36rpx;
}
.brand-block.compact {
  margin-bottom: 28rpx;
}
.logo-wrap {
  width: 120rpx;
  height: 120rpx;
  border-radius: 32rpx;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20rpx;
  box-shadow: 0 16rpx 40rpx rgba(21, 101, 192, 0.22);
  padding: 16rpx;
  box-sizing: border-box;
}
.logo {
  width: 100%;
  height: 100%;
}
.logo-wrap.sm {
  width: 96rpx;
  height: 96rpx;
  border-radius: 24rpx;
  padding: 12rpx;
  margin-bottom: 16rpx;
}
.brand {
  display: block;
  font-size: 48rpx;
  font-weight: 800;
  color: #0d2b4d;
  letter-spacing: 2rpx;
}
.back {
  display: flex;
  align-items: center;
  gap: 4rpx;
  margin-bottom: 20rpx;
  padding: 4rpx 0;
}
.back-arrow {
  font-size: 48rpx;
  line-height: 1;
  color: #1e88e5;
  font-weight: 300;
  margin-top: -4rpx;
}
.back-text {
  font-size: 30rpx;
  color: #1e88e5;
  font-weight: 600;
}
.title {
  display: block;
  margin-top: 10rpx;
  font-size: 34rpx;
  font-weight: 700;
  color: #122033;
  line-height: 1.35;
}
.sub {
  display: block;
  margin-top: 12rpx;
  font-size: 26rpx;
  color: #6b7a90;
  line-height: 1.5;
}
.section-title {
  display: block;
  margin: 8rpx 4rpx 16rpx;
  font-size: 26rpx;
  font-weight: 700;
  color: #5a6b80;
  letter-spacing: 1rpx;
}
.section-note {
  display: block;
  margin: -6rpx 4rpx 16rpx;
  font-size: 22rpx;
  color: #8a96a8;
}
.who {
  position: relative;
  display: block;
  padding: 28rpx 28rpx 28rpx 120rpx;
  margin-bottom: 16rpx;
}
.badge {
  position: absolute;
  left: 28rpx;
  top: 28rpx;
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  background: linear-gradient(145deg, #42a5f5, #1e88e5);
  color: #fff;
  font-size: 28rpx;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 10rpx 22rpx rgba(30, 136, 229, 0.28);
}
.badge.tech {
  background: linear-gradient(145deg, #26a69a, #00897b);
  box-shadow: 0 10rpx 22rpx rgba(0, 137, 123, 0.28);
}
.who-body,
.step-body {
  display: block;
  max-width: 100%;
  box-sizing: border-box;
}
.who-t,
.step-t,
.sample-name {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.who-d,
.step-d,
.sample-tip,
.sub,
.privacy,
.sample-meta {
  white-space: normal;
  word-break: break-word;
}
.who-d,
.step-d,
.sample-tip {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.5;
  color: #6b7a90;
}
.card {
  padding: 28rpx 32rpx 8rpx;
  margin-bottom: 28rpx;
}
.step {
  position: relative;
  display: block;
  padding-left: 62rpx;
  box-sizing: border-box;
}
.step-rail {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 44rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.step-no {
  width: 44rpx;
  height: 44rpx;
  border-radius: 50%;
  background: #1e88e5;
  color: #fff;
  font-size: 24rpx;
  font-weight: 700;
  text-align: center;
  line-height: 44rpx;
}
.step-line {
  width: 2rpx;
  flex: 1;
  min-height: 28rpx;
  background: #d6e4f5;
  margin: 6rpx 0;
}
.step-body {
  padding-bottom: 22rpx;
}
.sample {
  padding: 28rpx;
}
.sample-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.biz {
  font-size: 24rpx;
  font-weight: 700;
  color: #1e88e5;
}
.pill {
  font-size: 22rpx;
  color: #1e88e5;
  background: rgba(30, 136, 229, 0.1);
  border-radius: 999rpx;
  padding: 6rpx 16rpx;
}
.sample-name {
  margin-top: 16rpx;
}
.sample-meta,
.sample-no {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #6b7a90;
}
.sample-no {
  color: #9aa6b5;
  font-size: 22rpx;
}
.sample-tip {
  margin-top: 16rpx;
  padding-top: 16rpx;
  border-top: 1rpx solid #e8eef5;
}
.privacy {
  display: block;
  margin-top: 16rpx;
  font-size: 22rpx;
  line-height: 1.5;
  color: #8a96a8;
}
.dock {
  margin-top: 36rpx;
  padding-bottom: calc(8rpx + env(safe-area-inset-bottom));
}
.dock-row {
  display: flex;
  gap: 16rpx;
}
.dock-btn {
  flex: 1;
  width: 0;
  min-width: 0;
  height: 88rpx;
  line-height: 88rpx;
  text-align: center;
  font-size: 30rpx;
  border-radius: 18rpx;
  font-weight: 600;
  color: #fff;
}
.dock-btn.primary {
  background: linear-gradient(135deg, #42a5f5, #1e88e5);
  box-shadow: 0 12rpx 28rpx rgba(30, 136, 229, 0.32);
}
.dock-btn.tech {
  background: linear-gradient(135deg, #26a69a, #00897b);
  box-shadow: 0 12rpx 28rpx rgba(0, 137, 123, 0.28);
}
.apply-link {
  display: block;
  margin-top: 14rpx;
  text-align: center;
  font-size: 26rpx;
  color: #1e88e5;
  font-weight: 600;
}
.apply-link.mid {
  margin-top: 28rpx;
}
.form {
  padding: 8rpx 28rpx 36rpx;
}
.field {
  padding: 24rpx 0;
  border-bottom: 1rpx solid #e8eef5;
}
.label {
  display: block;
  font-size: 24rpx;
  color: #8a94a6;
  margin-bottom: 12rpx;
}
.input {
  height: 72rpx;
  font-size: 32rpx;
  color: #122033;
}
.ph {
  color: #b0b8c4;
}
.code-field {
  position: relative;
}
.code-input {
  width: 100%;
  padding-right: 180rpx;
  box-sizing: border-box;
}
.code-btn {
  position: absolute;
  right: 0;
  bottom: 20rpx;
  padding: 0 20rpx;
  height: 68rpx;
  line-height: 68rpx;
  font-size: 24rpx;
  color: #1e88e5;
  background: rgba(30, 136, 229, 0.1);
  border-radius: 14rpx;
  font-weight: 600;
}
.code-btn.off {
  color: #9aa3b2;
  background: #eef1f5;
}
.login-btn {
  margin-top: 36rpx;
  height: 92rpx;
  line-height: 92rpx;
  font-size: 32rpx;
}
.login-btn[disabled] {
  opacity: 0.55;
}
</style>
