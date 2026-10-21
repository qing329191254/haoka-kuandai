<template>
  <view class="page page-shell dense" v-if="order">
    <view class="banner">{{ bannerText }}</view>
    <view class="card surface">
      <text class="line">订单：{{ order.orderNo }}</text>
      <text class="line">业务：{{ orderBizLabel(order) }}</text>
      <text class="line">状态：{{ STATUS_LABEL[order.status] }}</text>
      <text class="line">套餐：{{ order.productName }}</text>
      <text class="line" v-if="order.orderIntent">意向：{{ order.orderIntent }}</text>
      <text class="line">客户：{{ order.customerName }} {{ order.customerPhone }}</text>
      <text class="line">地址：{{ order.address }}</text>
      <text class="line">运营商：{{ order.carrier }}</text>
    </view>
    <view class="hint surface">{{ hintText }}</view>
    <button v-if="canOpen" class="btn btn-primary" @click="confirmOpen">{{ openBtn }}</button>
    <button v-if="canInstall" class="btn warn" @click="finishInstall">确认装机完成</button>
    <view v-if="order.status === 'done'" class="done">本单已完成</view>
    <AppFeedback />
  </view>
  <view v-else class="page page-shell empty">订单不存在或无权查看</view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { STATUS_LABEL, orderBizLabel, type MpOrder } from '@/types/order'
import { showToast } from '@/store/feedback'
import { fetchOrder, markInstallDone, merchantBossPcOpen } from '@/store/orders'
import { requireRole } from '@/store/session'

const orderId = ref('')
const order = ref<MpOrder>()

const canOpen = computed(
  () => order.value && (order.value.status === 'listed' || order.value.status === 'merchant_accepted'),
)
const canInstall = computed(
  () => order.value && (order.value.status === 'boss_opened' || order.value.status === 'installing'),
)

const isNaked = computed(() => order.value?.bizType === 'broadband_naked')
const bannerText = computed(() =>
  isNaked.value ? '裸宽 · 商家办理装机' : '融合宽带（线上办理）· 商家电脑端开户 / 确认装机',
)
const hintText = computed(() =>
  isNaked.value
    ? '流程：接单 → 开始办理 → 装机完成后点确认。离开本页后可从接单池再次进入。'
    : '流程：接单 → 在运营商电脑端开户并点确认 → 装机完成后点确认。离开本页后可从接单池「确认装机」再次进入。',
)
const openBtn = computed(() => (isNaked.value ? '确认已开始办理' : '确认已完成开户'))

async function reload() {
  if (!requireRole('merchant')) return
  if (!orderId.value) return
  order.value = await fetchOrder(orderId.value)
}

onLoad((q) => {
  orderId.value = String(q?.id || '')
})

onShow(reload)

async function confirmOpen() {
  if (!order.value) return
  if (await merchantBossPcOpen(order.value.id)) {
    showToast(isNaked.value ? '已开始办理' : '已开户', { type: 'success', duration: 800 })
    setTimeout(() => uni.navigateBack(), 800)
  } else {
    showToast('当前状态不可开户', { type: 'error' })
  }
}

async function finishInstall() {
  if (!order.value) return
  if (await markInstallDone(order.value.id)) {
    showToast('装机完成', { type: 'success', duration: 800 })
    setTimeout(() => uni.navigateBack(), 800)
  } else {
    showToast('请先完成开户', { type: 'error' })
  }
}
</script>

<style scoped>
.banner {
  background: linear-gradient(135deg, rgba(30, 136, 229, 0.16), rgba(66, 165, 245, 0.1));
  color: #1565c0;
  padding: 22rpx 24rpx;
  border-radius: 20rpx;
  font-size: 26rpx;
  font-weight: 600;
  margin-bottom: 20rpx;
  border: 1rpx solid rgba(30, 136, 229, 0.12);
}
.card {
  padding: 26rpx 24rpx;
}
.line {
  display: block;
  margin-bottom: 12rpx;
  color: #3a4a5e;
  font-size: 28rpx;
}
.hint {
  margin: 20rpx 0;
  padding: 22rpx 24rpx;
  color: #6b7a90;
  font-size: 24rpx;
  line-height: 1.6;
}
.done {
  margin-top: 32rpx;
  text-align: center;
  color: #2e7d32;
  font-size: 28rpx;
  font-weight: 700;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding-top: 120rpx;
}
.btn {
  margin-top: 16rpx;
  height: 88rpx;
  line-height: 88rpx;
  border-radius: 18rpx;
  font-weight: 600;
}
.btn.warn {
  background: linear-gradient(135deg, #ffb74d, #ef6c00);
  color: #fff;
  box-shadow: 0 12rpx 28rpx rgba(239, 108, 0, 0.28);
}
.btn.warn::after {
  border: none;
}
</style>
