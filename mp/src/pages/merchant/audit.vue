<template>
  <view class="page page-shell" v-if="session">
    <view class="card surface">
      <view class="icon-wrap" :class="session.auditStatus === 'rejected' ? 'warn' : 'info'">
        <text class="icon">{{ icon }}</text>
      </view>
      <text class="title">{{ title }}</text>
      <text class="body">{{ body }}</text>
      <text class="phone">登录手机号 {{ session.phone }}</text>
    </view>
    <button v-if="session.auditStatus === 'rejected'" class="btn btn-primary" @click="reApply">重新申请</button>
    <button class="btn ghost" @click="onLogout">退出登录</button>
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { showConfirm } from '@/store/feedback'
import { getSession, clearSession, logout, refreshMerchantSession, type MpSession } from '@/store/session'
import { hideMpHomeButton } from '@/utils/hideHomeButton'

const session = ref<MpSession | null>(null)

onShow(async () => {
  hideMpHomeButton()
  session.value = (await refreshMerchantSession()) || getSession()
  if (!session.value || session.value.role !== 'merchant') {
    uni.reLaunch({ url: '/pages/index/index' })
    return
  }
  if (session.value.auditStatus === 'approved') {
    uni.reLaunch({ url: '/pages/merchant/home' })
  }
})

const icon = computed(() => (session.value?.auditStatus === 'rejected' ? '✕' : '…'))
const title = computed(() =>
  session.value?.auditStatus === 'rejected' ? '入驻申请未通过' : '入驻申请审核中',
)
const body = computed(() => {
  if (session.value?.auditStatus === 'rejected') {
    return session.value.rejectReason || '请完善资料后重新申请，或联系平台客服。'
  }
  return `我们已收到「${session.value?.displayName || ''}」的申请，运营审核通过后即可登录接单。`
})

function reApply() {
  clearSession()
  uni.reLaunch({ url: '/pages/merchant/apply' })
}

async function onLogout() {
  const ok = await showConfirm({
    title: '退出登录',
    content: '退出后需重新用手机号登录',
    confirmText: '退出',
    cancelText: '再想想',
    tone: 'primary',
    icon: '←',
  })
  if (ok) logout()
}
</script>

<style scoped>
.card {
  padding: 56rpx 36rpx 48rpx;
  text-align: center;
}
.icon-wrap {
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  margin: 0 auto 24rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}
.icon-wrap.info {
  background: linear-gradient(145deg, #42a5f5, #1e88e5);
  box-shadow: 0 12rpx 28rpx rgba(30, 136, 229, 0.3);
}
.icon-wrap.warn {
  background: linear-gradient(145deg, #ffb74d, #ef6c00);
  box-shadow: 0 12rpx 28rpx rgba(239, 108, 0, 0.3);
}
.icon {
  font-size: 44rpx;
  color: #fff;
  font-weight: 700;
}
.title {
  display: block;
  font-size: 34rpx;
  font-weight: 700;
  color: #122033;
}
.body {
  display: block;
  margin-top: 16rpx;
  font-size: 26rpx;
  color: #6b7a90;
  line-height: 1.55;
}
.phone {
  display: block;
  margin-top: 20rpx;
  font-size: 22rpx;
  color: #9aa3b2;
}
.btn {
  margin-top: 28rpx;
  height: 88rpx;
  line-height: 88rpx;
  border-radius: 18rpx;
  font-size: 30rpx;
  font-weight: 600;
}
.btn.ghost {
  background: rgba(255, 255, 255, 0.92);
  color: #1e88e5;
  border: 1rpx solid rgba(30, 136, 229, 0.35);
}
.btn.ghost::after {
  border: none;
}
</style>
