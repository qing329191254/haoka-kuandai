<template>
  <view class="page page-shell dense" v-if="order">
    <view class="card surface">
      <text class="title">{{ order.productName }}</text>
      <text class="line">{{ order.customerName }} · {{ order.customerPhone }}</text>
      <text class="line">{{ order.orderNo }}</text>
    </view>

    <view class="form surface">
      <text class="label">原因</text>
      <view class="reasons">
        <text
          v-for="r in reasons"
          :key="r"
          :class="['chip', reason === r ? 'on' : '']"
          @click="reason = r"
        >
          {{ r }}
        </text>
      </view>

      <text class="label">下次联系时间（选填）</text>
      <input v-model="nextAt" class="input" placeholder="如 2026-08-28 10:00" />

      <text class="label">备注</text>
      <textarea v-model="note" class="textarea" placeholder="选填" />
    </view>

    <button class="btn btn-primary" @click="submit">保存</button>
    <AppFeedback />
  </view>
  <view v-else class="page page-shell empty">订单不存在</view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { showToast, withLoading } from '@/store/feedback'
import { fetchOrder, merchantMarkFollowUp } from '@/store/orders'
import { requireRole } from '@/store/session'
import type { MpOrder } from '@/types/order'

const reasons = ['联系不上', '客户暂不方便', '资料不全', '验证码失败', '上门未成功', '其他']

const orderId = ref('')
const order = ref<MpOrder>()
const reason = ref(reasons[0])
const nextAt = ref('')
const note = ref('')

async function reload() {
  if (!requireRole('merchant')) return
  order.value = await fetchOrder(orderId.value)
  if (order.value?.followUpReason) reason.value = order.value.followUpReason
  if (order.value?.nextFollowUpAt) nextAt.value = order.value.nextFollowUpAt
}

onLoad((q) => {
  orderId.value = String(q?.id || '')
})

onShow(reload)

async function submit() {
  if (!order.value) return
  if (!reason.value.trim()) {
    showToast('请选择跟进原因', { type: 'error' })
    return
  }
  if (
    await withLoading(
      () => merchantMarkFollowUp(orderId.value, reason.value, nextAt.value, note.value),
      '提交中…',
    )
  ) {
    showToast('已保存', { type: 'success', duration: 800 })
    setTimeout(() => uni.navigateBack(), 800)
  } else {
    showToast('保存失败', { type: 'error' })
  }
}
</script>

<style scoped>
.card {
  padding: 26rpx 24rpx;
  margin-bottom: 16rpx;
}
.title {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.line {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #7a8699;
}
.form {
  padding: 24rpx;
  margin-bottom: 16rpx;
}
.label {
  display: block;
  font-size: 24rpx;
  font-weight: 700;
  color: #5a6b80;
  margin-bottom: 12rpx;
}
.reasons {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-bottom: 24rpx;
}
.chip {
  padding: 10rpx 20rpx;
  border-radius: 999rpx;
  font-size: 24rpx;
  color: #5a6b80;
  background: #f4f7fb;
  border: 1rpx solid rgba(18, 56, 110, 0.08);
}
.chip.on {
  color: #1e88e5;
  background: rgba(30, 136, 229, 0.12);
  border-color: rgba(30, 136, 229, 0.25);
}
.input {
  width: 100%;
  padding: 18rpx 20rpx;
  border-radius: 14rpx;
  background: #f8fafc;
  font-size: 26rpx;
  margin-bottom: 24rpx;
  box-sizing: border-box;
}
.textarea {
  width: 100%;
  min-height: 160rpx;
  padding: 18rpx 20rpx;
  border-radius: 14rpx;
  background: #f8fafc;
  font-size: 26rpx;
  box-sizing: border-box;
}
.btn {
  height: 88rpx;
  line-height: 88rpx;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding-top: 120rpx;
}
</style>
