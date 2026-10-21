<template>
  <view class="page page-shell">
    <view v-if="booting" class="boot">
      <view class="logo-wrap">
        <image class="logo" src="/static/logo.png" mode="aspectFit" />
      </view>
      <text class="boot-t">派客邦</text>
    </view>

    <template v-else>
      <view class="brand-block">
        <view class="logo-wrap">
          <image class="logo" src="/static/splash_logo.png" mode="aspectFit" />
        </view>
        <text class="brand">派客邦</text>
        <text class="title">本地商家 · 上门师傅</text>
        <text class="sub">请选择工作身份登录</text>
      </view>

      <view class="role-card surface tap-feedback" @click="goLogin('merchant')">
        <view class="role-left">
          <view class="badge">商</view>
          <view class="role-text">
            <text class="role-title">商家</text>
            <text class="role-desc">接单、派单、电脑开户、管理师傅</text>
          </view>
        </view>
        <text class="arrow">›</text>
      </view>

      <view class="role-card surface tap-feedback" @click="goLogin('technician')">
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

    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShareAppMessage, onShareTimeline, onShow } from '@dcloudio/uni-app'
import type { Role } from '@/types/order'
import AppFeedback from '@/components/AppFeedback.vue'
import { getSession, goRoleHome } from '@/store/session'
import { hideMpHomeButton } from '@/utils/hideHomeButton'
import { getMpShareAppMessage, getMpShareTimeline } from '@/utils/mpShare'

onShareAppMessage(() => getMpShareAppMessage())
onShareTimeline(() => getMpShareTimeline())

const booting = ref(true)
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

function openLogin(role: Role, replace = false) {
  const url = `/pages/login/login?role=${role}`
  if (replace) uni.redirectTo({ url })
  else uni.navigateTo({ url })
}

onLoad((query) => {
  if (resumeIfLoggedIn()) return
  const roleQuery = query?.role
  if (roleQuery === 'merchant' || roleQuery === 'technician') {
    // 深链 / 旧入口带 role：直接进登录二级页
    openLogin(roleQuery, true)
  }
})

onShow(() => {
  hideMpHomeButton()
  resumeIfLoggedIn()
})

function goLogin(role: Role) {
  openLogin(role)
}

function goApply() {
  uni.navigateTo({ url: '/pages/merchant/apply' })
}

function goGuide() {
  uni.navigateTo({ url: '/pages/guide/index' })
}
</script>

<style scoped>
.page {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  overflow-x: hidden;
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
.brand-block {
  margin-bottom: 40rpx;
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
.brand {
  display: block;
  font-size: 48rpx;
  font-weight: 800;
  color: #0d2b4d;
  letter-spacing: 2rpx;
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
</style>
