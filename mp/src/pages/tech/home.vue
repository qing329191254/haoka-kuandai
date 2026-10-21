<template>
  <view class="page page-shell" v-if="session">
    <view class="hero-panel tech-hero">
      <view class="hero-top">
        <view>
          <text class="hello">你好，{{ session.displayName }}</text>
          <text class="role">上门师傅 · {{ session.phone }}</text>
        </view>
        <text class="logout" @click="onLogout">退出</text>
      </view>
      <view class="stats">
        <view class="stat" @click="goTasks('todo')">
          <text class="n">{{ stats.todo }}</text>
          <text class="l">待上门</text>
        </view>
        <view class="stat" @click="goTasks('serving')">
          <text class="n">{{ stats.serving }}</text>
          <text class="l">服务中</text>
        </view>
        <view class="stat" @click="goTasks('done')">
          <text class="n">{{ stats.done }}</text>
          <text class="l">已完成</text>
        </view>
        <view class="stat" @click="goTasks('returned')">
          <text class="n">{{ stats.returned }}</text>
          <text class="l">已退回</text>
        </view>
      </view>
    </view>

    <text class="section-title">按业务类型查看任务</text>
    <view class="grid">
      <view v-for="g in groups" :key="g.key" class="cell surface" @click="goBiz(g.key)">
        <view class="icon">{{ g.label.slice(0, 1) }}</view>
        <view class="cell-body">
          <text class="cell-t">{{ g.label }}</text>
          <text class="cell-d">{{ groupDesc(g) }}</text>
        </view>
        <text class="chev">›</text>
      </view>
    </view>

    <view class="tips surface">
      <text class="tips-t">上门须知</text>
      <text class="tips-d"
        >交付成功请拍摄现场照片。无法完成上门请填写原因，订单将交回商家跟进；如需再次上门，由商家重新派单。</text
      >
    </view>

    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { showConfirm } from '@/store/feedback'
import { techBizGroups, techStats } from '@/store/orders'
import { logout, requireRole, type MpSession } from '@/store/session'

const session = ref<MpSession | null>(null)
const stats = ref({ todo: 0, serving: 0, done: 0, returned: 0 })
const groups = ref<{ key: string; label: string; todo: number; serving: number; returned: number }[]>([])

onShow(async () => {
  session.value = requireRole('technician')
  if (session.value) {
    stats.value = await techStats()
    groups.value = await techBizGroups()
  }
})

function goTasks(tab?: 'todo' | 'serving' | 'done' | 'returned') {
  const q = tab ? `?tab=${tab}` : ''
  uni.navigateTo({ url: `/pages/tech/tasks${q}` })
}

function goBiz(biz: string) {
  uni.navigateTo({ url: `/pages/tech/tasks?biz=${encodeURIComponent(biz)}` })
}

function groupDesc(g: { todo: number; serving: number; returned: number }) {
  return `待上门 ${g.todo} · 服务中 ${g.serving} · 已退回 ${g.returned}`
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
.tech-hero {
  background: linear-gradient(135deg, #054640 0%, #00796b 55%, #26a69a 100%);
  box-shadow: 0 20rpx 48rpx rgba(0, 77, 64, 0.28);
}
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
  background: linear-gradient(145deg, #26a69a, #00897b);
  color: #fff;
  font-size: 28rpx;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 10rpx 22rpx rgba(0, 137, 123, 0.28);
  flex-shrink: 0;
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
.tips {
  margin-top: 28rpx;
  padding: 24rpx;
}
.tips-t {
  display: block;
  font-size: 24rpx;
  font-weight: 700;
  color: #00897b;
  margin-bottom: 8rpx;
}
.tips-d {
  display: block;
  font-size: 24rpx;
  color: #5a6b80;
  line-height: 1.55;
}
</style>
