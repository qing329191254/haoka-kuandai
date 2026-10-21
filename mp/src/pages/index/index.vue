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
        <text class="title">本地商家 · 上门师傅</text>
        <text class="sub">请选择工作身份登录</text>
      </view>

      <view class="role-card surface" @click="chooseRole('merchant')">
        <view class="role-left">
          <view class="badge">商</view>
          <view class="role-text">
            <text class="role-title">商家</text>
            <text class="role-desc">接单、派单、电脑开户、管理师傅</text>
          </view>
        </view>
        <text class="arrow">›</text>
      </view>

      <view class="role-card surface" @click="chooseRole('technician')">
        <view class="role-left">
          <view class="badge tech">师</view>
          <view class="role-text">
            <text class="role-title">上门师傅</text>
            <text class="role-desc">接单上门、手机开户、装机确认</text>
          </view>
        </view>
        <text class="arrow">›</text>
      </view>

      <button class="guide-btn" @click="goGuide">使用说明</button>

      <text class="foot">商家需先入驻申请并经运营审核；师傅由所属商家添加</text>
      <text class="apply-link" @click="goApply">商家入驻申请 ›</text>
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

function goGuide() {
  uni.navigateTo({ url: '/pages/guide/index' })
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
  margin-bottom: 40rpx;
}
.brand-block.compact {
  margin-bottom: 28rpx;
}
.logo-wrap {
  width: 148rpx;
  height: 148rpx;
  border-radius: 36rpx;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
  box-shadow: 0 16rpx 40rpx rgba(21, 101, 192, 0.22);
  padding: 20rpx;
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
  font-size: 36rpx;
  font-weight: 700;
  color: #122033;
}
.sub {
  display: block;
  margin-top: 12rpx;
  font-size: 26rpx;
  color: #6b7a90;
  line-height: 1.45;
}
.role-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 32rpx 28rpx;
  margin-bottom: 20rpx;
}
.role-left {
  display: flex;
  align-items: center;
  gap: 22rpx;
  min-width: 0;
  flex: 1;
}
.badge {
  width: 84rpx;
  height: 84rpx;
  border-radius: 22rpx;
  background: linear-gradient(145deg, #42a5f5, #1e88e5);
  color: #fff;
  font-size: 32rpx;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 12rpx 24rpx rgba(30, 136, 229, 0.3);
}
.badge.tech {
  background: linear-gradient(145deg, #26a69a, #00897b);
  box-shadow: 0 12rpx 24rpx rgba(0, 137, 123, 0.3);
}
.role-text {
  flex: 1;
  min-width: 0;
}
.role-title {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #122033;
}
.role-desc {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #7a8699;
}
.arrow {
  font-size: 40rpx;
  color: #b0bccf;
  font-weight: 300;
  flex-shrink: 0;
  margin-left: 12rpx;
}
.guide-btn {
  margin: 8rpx 0 0;
  height: 84rpx;
  line-height: 84rpx;
  font-size: 28rpx;
  font-weight: 600;
  color: #1e88e5;
  background: rgba(255, 255, 255, 0.72);
  border-radius: 18rpx;
}
.guide-btn::after {
  border: none;
}
.foot {
  display: block;
  margin-top: 28rpx;
  text-align: center;
  font-size: 22rpx;
  color: #8a96a8;
  line-height: 1.5;
}
.apply-link {
  display: block;
  margin-top: 18rpx;
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
