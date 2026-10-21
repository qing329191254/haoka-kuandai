<template>
  <view class="page page-shell dense" v-if="order">
    <view class="card surface">
      <text class="line"><text class="k">订单号</text>{{ order.orderNo }}</text>
      <text class="line"><text class="k">业务</text>{{ orderBizLabel(order) }}</text>
      <text class="line"><text class="k">状态</text>{{ STATUS_LABEL[order.status] }}</text>
      <text class="line"><text class="k">套餐</text>{{ order.productName }}</text>
      <text class="line" v-if="order.orderIntent"><text class="k">意向</text>{{ order.orderIntent }}</text>
      <text class="line" v-if="order.phoneBrand"><text class="k">品牌</text>{{ order.phoneBrand }}</text>
      <text class="line" v-if="order.priceRange"><text class="k">价位</text>{{ order.priceRange }}</text>
      <text class="line" v-if="order.wifiDeviceType"><text class="k">设备</text>{{ order.wifiDeviceType }} {{ order.wifiBizMode || '' }}</text>
      <text class="line"><text class="k">客户</text>{{ order.customerName }} {{ order.customerPhone }}</text>
      <text class="line"><text class="k">地址</text>{{ order.address }}</text>
      <text class="line"><text class="k">商家</text>{{ order.merchantName || '-' }}</text>
      <text class="line"><text class="k">师傅</text>{{ order.technicianName || '-' }}</text>
      <text class="line" v-if="order.followUpReason"><text class="k">跟进原因</text>{{ order.followUpReason }}</text>
      <text class="line" v-if="order.nextFollowUpAt"><text class="k">下次联系</text>{{ order.nextFollowUpAt }}</text>
      <text class="line" v-if="order.failReason"><text class="k">失败说明</text>{{ order.failReason }}</text>
      <view v-if="order.followUpLogs?.length" class="logs">
        <text class="k">跟进记录</text>
        <view v-for="(log, i) in order.followUpLogs" :key="i" class="log-item">
          <text class="log-time">{{ log.time }}</text>
          <text class="log-note">{{ log.actor ? `${log.actor}：` : '' }}{{ log.note }}</text>
        </view>
      </view>
      <view v-if="order.deliveryPhotos?.length" class="photos">
        <text class="k">交付照片</text>
        <image v-for="(src, i) in order.deliveryPhotos" :key="i" class="photo" :src="src" mode="aspectFill" />
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import { STATUS_LABEL, orderBizLabel, type MpOrder } from '@/types/order'
import { fetchOrder } from '@/store/orders'

const order = ref<MpOrder>()

const orderId = ref('')

async function reload() {
  if (!orderId.value) return
  order.value = await fetchOrder(orderId.value)
}

onLoad((q) => {
  orderId.value = String(q?.id || '')
  reload()
})

onShow(reload)
</script>

<style scoped>
.card {
  padding: 28rpx 24rpx;
}
.line {
  display: block;
  margin-bottom: 16rpx;
  font-size: 28rpx;
  color: #122033;
}
.k {
  display: inline-block;
  width: 140rpx;
  color: #8a94a6;
}
.logs {
  margin-top: 8rpx;
}
.log-item {
  margin-top: 12rpx;
  padding: 16rpx;
  background: #f8fafc;
  border-radius: 12rpx;
}
.log-time {
  display: block;
  font-size: 22rpx;
  color: #a0aab8;
}
.log-note {
  display: block;
  margin-top: 4rpx;
  font-size: 26rpx;
  color: #3a4a5e;
  line-height: 1.5;
}
.photos {
  margin-top: 8rpx;
}
.photo {
  width: 160rpx;
  height: 160rpx;
  border-radius: 12rpx;
  margin: 12rpx 12rpx 0 0;
}
</style>
