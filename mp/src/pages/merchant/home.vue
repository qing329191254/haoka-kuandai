<template>
  <view class="page page-shell" v-if="session">
    <view class="hero-panel">
      <view class="hero-top">
        <view>
          <text class="hello">你好，{{ session.displayName }}</text>
          <text class="role">本地商家 · {{ session.phone }}</text>
        </view>
        <text class="logout" @click="onLogout">退出</text>
      </view>
      <view class="stats">
        <view class="stat tap-feedback" @click="goStage('entry')">
          <text class="n">{{ stats.entry }}</text>
          <text class="l">待接单</text>
        </view>
        <view class="stat tap-feedback" @click="goStage('process')">
          <text class="n">{{ stats.process }}</text>
          <text class="l">办理中</text>
        </view>
        <view class="stat tap-feedback" @click="goStage('dispatch')">
          <text class="n">{{ stats.dispatch }}</text>
          <text class="l">派单上门</text>
        </view>
      </view>
    </view>

    <text class="section-title">工作台</text>
    <view class="grid">
      <view class="cell surface tap-feedback" @click="goStage('entry')">
        <view class="icon">录</view>
        <view class="cell-body">
          <text class="cell-t">订单录入</text>
          <text class="cell-d">新录入订单</text>
        </view>
        <text class="chev">›</text>
      </view>
      <view class="cell surface tap-feedback" @click="goStage('process')">
        <view class="icon alt2">办</view>
        <view class="cell-body">
          <text class="cell-t">订单办理</text>
          <text class="cell-d">办理与跟进</text>
        </view>
        <text class="chev">›</text>
      </view>
      <view class="cell surface tap-feedback" @click="goStage('dispatch')">
        <view class="icon alt">派</view>
        <view class="cell-body">
          <text class="cell-t">派单上门</text>
          <text class="cell-d">派单与上门</text>
        </view>
        <text class="chev">›</text>
      </view>
      <view class="cell surface tap-feedback" @click="goTechs">
        <view class="icon alt3">师</view>
        <view class="cell-body">
          <text class="cell-t">上门师傅</text>
          <text class="cell-d">新增 / 管理本店师傅</text>
        </view>
        <text class="chev">›</text>
      </view>
    </view>

    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { showConfirm } from '@/store/feedback'
import { merchantStats, type MerchantStats } from '@/store/orders'
import { logout, requireRole, type MpSession } from '@/store/session'
import { hideMpHomeButton } from '@/utils/hideHomeButton'
import type { WorkStage } from '@/utils/workStage'

const session = ref<MpSession | null>(null)
const stats = ref<MerchantStats>({ entry: 0, process: 0, dispatch: 0, followUp: 0, done: 0 })

function refreshStats() {
  merchantStats().then((next) => {
    stats.value.entry = next.entry
    stats.value.process = next.process
    stats.value.dispatch = next.dispatch
    stats.value.followUp = next.followUp
    stats.value.done = next.done
  })
}

onShow(() => {
  hideMpHomeButton()
  session.value = requireRole('merchant')
  if (session.value) refreshStats()
})

function goStage(stage: WorkStage) {
  uni.navigateTo({ url: `/pages/merchant/pool?stage=${stage}` })
}

function goTechs() {
  uni.navigateTo({ url: '/pages/merchant/techs' })
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
.hero-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  position: relative;
  z-index: 1;
}
.hello {
  display: block;
  font-size: 38rpx;
  font-weight: 700;
  color: #fff;
}
.role {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.72);
}
.logout {
  font-size: 24rpx;
  color: #fff;
  padding: 10rpx 20rpx;
  border-radius: 999rpx;
  background: rgba(255, 255, 255, 0.16);
  border: 1rpx solid rgba(255, 255, 255, 0.22);
}
.stats {
  display: flex;
  margin-top: 32rpx;
  position: relative;
  z-index: 1;
  background: rgba(255, 255, 255, 0.12);
  border-radius: 20rpx;
  padding: 22rpx 0;
  border: 1rpx solid rgba(255, 255, 255, 0.14);
}
.stat {
  flex: 1;
  text-align: center;
}
.n {
  display: block;
  font-size: 40rpx;
  font-weight: 700;
  color: #fff;
}
.l {
  display: block;
  margin-top: 4rpx;
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.7);
}
.section-title {
  display: block;
  font-size: 26rpx;
  font-weight: 700;
  color: #5a6b80;
  margin-bottom: 16rpx;
  letter-spacing: 1rpx;
}
.grid {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}
.cell {
  padding: 26rpx 24rpx;
  display: flex;
  align-items: center;
  gap: 20rpx;
}
.icon {
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
  box-shadow: 0 10rpx 22rpx rgba(30, 136, 229, 0.28);
  flex-shrink: 0;
}
.icon.alt {
  background: linear-gradient(145deg, #ffb74d, #ef6c00);
  box-shadow: 0 10rpx 22rpx rgba(239, 108, 0, 0.28);
}
.icon.alt2 {
  background: linear-gradient(145deg, #26a69a, #00897b);
  box-shadow: 0 10rpx 22rpx rgba(0, 137, 123, 0.28);
}
.icon.alt3 {
  background: linear-gradient(145deg, #7e57c2, #5e35b1);
  box-shadow: 0 10rpx 22rpx rgba(94, 53, 177, 0.28);
}
.cell-body {
  flex: 1;
}
.cell-t {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.cell-d {
  display: block;
  margin-top: 6rpx;
  font-size: 24rpx;
  color: #7a8699;
}
.chev {
  font-size: 36rpx;
  color: #c0cad8;
}
</style>
