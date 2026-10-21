<template>
  <view class="page page-shell login-page">
    <text class="hint">{{
      role === 'merchant' ? '使用已通过审核的手机号登录' : '使用商家为您开通的手机号登录'
    }}</text>

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

      <view class="agree-row" @click="toggleAgree">
        <view class="agree-box" :class="{ on: agreed }">
          <text v-if="agreed" class="agree-check">✓</text>
        </view>
        <view class="agree-text">
          <text class="legal-t">我已阅读并同意</text>
          <text class="legal-link" @click.stop="openDoc('agreement')">《用户协议》</text>
          <text class="legal-t">和</text>
          <text class="legal-link" @click.stop="openDoc('privacy')">《隐私政策》</text>
        </view>
      </view>

      <button class="login-btn btn-primary" :disabled="loading" @click="onLogin">登录</button>
      <text v-if="role === 'merchant'" class="apply-link" @click="goApply">还没有门店？申请入驻</text>
    </view>

    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShow, onUnload } from '@dcloudio/uni-app'
import type { Role } from '@/types/order'
import AppFeedback from '@/components/AppFeedback.vue'
import { request } from '@/api/http'
import { showConfirm, showToast, withLoading } from '@/store/feedback'
import { getSession, goRoleHome, loginByPhone } from '@/store/session'
import { hideMpHomeButton } from '@/utils/hideHomeButton'

const role = ref<Role>('merchant')
const phone = ref('')
const code = ref('')
const agreed = ref(false)
const loading = ref(false)
const countdown = ref(0)
let timer: ReturnType<typeof setInterval> | null = null
let navTimer: ReturnType<typeof setTimeout> | null = null

onLoad((query) => {
  const r = query?.role
  role.value = r === 'technician' ? 'technician' : 'merchant'
  uni.setNavigationBarTitle({
    title: role.value === 'merchant' ? '商家登录' : '师傅登录',
  })
})

onShow(() => {
  hideMpHomeButton()
})

onUnload(() => {
  if (timer) clearInterval(timer)
  if (navTimer) clearTimeout(navTimer)
})

function goApply() {
  uni.navigateTo({ url: '/pages/merchant/apply' })
}

function openDoc(id: 'agreement' | 'privacy') {
  uni.navigateTo({ url: `/pages/doc/index?id=${id}` })
}

function toggleAgree() {
  agreed.value = !agreed.value
}

async function ensureAgreed() {
  if (agreed.value) return true
  const ok = await showConfirm({
    title: '用户协议与隐私政策',
    content: '请阅读并同意《用户协议》和《隐私政策》后继续登录',
    confirmText: '同意并登录',
    cancelText: '取消',
    tone: 'primary',
  })
  if (!ok) return false
  agreed.value = true
  return true
}

async function sendCode() {
  if (!/^1\d{10}$/.test(phone.value.trim())) {
    showToast('请先填写正确手机号', { type: 'error' })
    return
  }
  if (countdown.value > 0) return
  try {
    await withLoading(
      () => request({ url: '/api/mp/auth/sms', method: 'POST', data: { phone: phone.value.trim() } }),
      '发送中…',
    )
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
  if (!(await ensureAgreed())) return

  loading.value = true
  const err = await withLoading(() => loginByPhone(p, role.value, c), '登录中…')
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
  box-sizing: border-box;
  overflow-x: hidden;
}
.login-page {
  padding-top: 12rpx;
}
.hint {
  display: block;
  margin-bottom: 24rpx;
  font-size: 26rpx;
  color: #6b7a90;
  line-height: 1.45;
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
.agree-row {
  display: flex;
  flex-direction: row;
  align-items: center;
  margin-top: 32rpx;
  padding: 4rpx 0;
}
.agree-box {
  flex-shrink: 0;
  width: 28rpx;
  height: 28rpx;
  margin-right: 12rpx;
  border-radius: 6rpx;
  border: 2rpx solid #c5ced9;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
}
.agree-box.on {
  border-color: #1e88e5;
  background: #1e88e5;
}
.agree-check {
  font-size: 18rpx;
  color: #fff;
  font-weight: 700;
  line-height: 28rpx;
}
.agree-text {
  flex: 1;
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  font-size: 24rpx;
  line-height: 28rpx;
}
.legal-t {
  font-size: 24rpx;
  line-height: 28rpx;
  color: #8a94a6;
}
.legal-link {
  font-size: 24rpx;
  line-height: 28rpx;
  color: #1e88e5;
  font-weight: 600;
}
.login-btn {
  margin-top: 28rpx;
  height: 92rpx;
  line-height: 92rpx;
  font-size: 32rpx;
}
.login-btn[disabled] {
  opacity: 0.55;
}
.apply-link {
  display: block;
  margin-top: 28rpx;
  text-align: center;
  font-size: 26rpx;
  color: #1e88e5;
  font-weight: 600;
}
</style>
