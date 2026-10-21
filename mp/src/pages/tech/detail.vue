<template>
  <view class="page page-shell dense" v-if="order">
    <view class="card surface">
      <text class="title">{{ order.productName }}</text>
      <text class="line">类型：{{ orderBizLabel(order) }}</text>
      <text class="line">状态：{{ STATUS_LABEL[order.status] }}</text>
      <text class="line">客户：{{ order.customerName }} {{ order.customerPhone }}</text>
      <text class="line">地址：{{ order.address }}</text>
      <text class="line">师傅：{{ order.technicianName || '-' }}</text>
      <text class="line" v-if="order.phoneBrand">手机品牌：{{ order.phoneBrand }}</text>
      <text class="line" v-if="order.priceRange">价格区间：{{ order.priceRange }}</text>
      <text class="line" v-if="order.wifiDeviceType">设备类型：{{ order.wifiDeviceType }}</text>
      <text class="line" v-if="order.wifiBizMode">业务模式：{{ order.wifiBizMode }}</text>
      <text class="line" v-if="order.orderIntent">客户意向：{{ order.orderIntent }}</text>
      <text class="line" v-if="order.carrier">运营商 / WIFI 公司：{{ order.carrier }}</text>
    </view>

    <view v-if="order.failReason" class="fail surface">
      <text class="fail-t">退回原因</text>
      <text class="fail-d">{{ order.failReason }}</text>
    </view>

    <view v-if="order.deliveryPhotos?.length" class="photos surface">
      <text class="photos-t">交付照片</text>
      <view class="photo-row">
        <image v-for="(src, i) in order.deliveryPhotos" :key="i" class="photo" :src="src" mode="aspectFill" />
      </view>
    </view>

    <view class="hint surface">{{ hintText }}</view>

    <button v-if="order.status === 'dispatched'" class="btn teal" @click="accept">接单上门</button>

    <button
      v-if="order.status === 'tech_accepted' && (order.bizType === 'haoka' || order.bizType === 'broadband_new_card')"
      class="btn teal"
      @click="bossOpen"
    >
      {{ order.bizType === 'haoka' ? '手机开户激活' : '手机端开户' }}
    </button>

    <view v-if="showDeliver" class="deliver">
      <view class="photos surface">
        <text class="photos-t">交付照片（成功必传）</text>
        <view class="photo-row">
          <image v-for="(src, i) in photos" :key="i" class="photo" :src="src" mode="aspectFill" @click="preview(i)" />
          <view class="add" @click="pickPhotos">+ 拍照/相册</view>
        </view>
      </view>
      <button class="btn teal" @click="deliverOk">交付成功</button>
      <button class="btn danger" @click="deliverFail">无法交付，交回商家</button>
    </view>

    <view v-if="order.status === 'done'" class="done">本单已完成</view>
    <view v-if="order.status === 'follow_up' || order.status === 'failed'" class="fail-end">
      已交回商家跟进，如需再次上门由商家重新派单
    </view>
    <AppFeedback />
  </view>
  <view v-else class="page page-shell empty">任务不存在</view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { uploadImage } from '@/api/http'
import { STATUS_LABEL, orderBizLabel, type MpOrder } from '@/types/order'
import { showConfirm, showToast } from '@/store/feedback'
import { canDeliver, fetchOrder, techAccept, techBossMobileOpen, techDeliverFail, techDeliverSuccess } from '@/store/orders'
import { requireRole } from '@/store/session'

const orderId = ref('')
const order = ref<MpOrder>()
const photos = ref<string[]>([])

const showDeliver = computed(() => !!order.value && canDeliver(order.value))

const hintText = computed(() => {
  const t = order.value?.bizType
  if (t === 'haoka') return '请先完成手机开户激活，再拍照确认交付。无法完成请交回商家跟进。'
  if (t === 'broadband_new_card') return '请先在运营商手机端开户，再拍照确认交付。无法完成请交回商家跟进。'
  return '交付成功请上传现场照片；无法完成请填写原因，订单将交回商家跟进。'
})

function goBackAfterSuccess(msg: string, tab?: 'todo' | 'serving' | 'done' | 'returned') {
  if (tab) uni.setStorageSync('tech_tasks_prefer_tab', tab)
  showToast(msg, { type: 'success', duration: 800 })
  setTimeout(() => uni.navigateBack(), 800)
}

async function reload() {
  if (!requireRole('technician')) return
  order.value = await fetchOrder(orderId.value)
}

onLoad((q) => {
  orderId.value = String(q?.id || '')
})

onShow(reload)

async function accept() {
  if (!order.value) return
  if (await techAccept(order.value.id)) {
    goBackAfterSuccess('已接单', 'serving')
  } else {
    showToast('接单失败（可能已被他人接走）', { type: 'error' })
  }
}

async function bossOpen() {
  if (!order.value) return
  if (await techBossMobileOpen(order.value.id)) {
    goBackAfterSuccess('开户成功', 'serving')
  } else {
    showToast('当前不可开户', { type: 'error' })
  }
}

function pickPhotos() {
  uni.chooseImage({
    count: Math.max(1, 9 - photos.value.length),
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      photos.value = [...photos.value, ...res.tempFilePaths].slice(0, 9)
    },
  })
}

function preview(i: number) {
  uni.previewImage({ urls: photos.value, current: photos.value[i] })
}

async function deliverOk() {
  if (!order.value) return
  if (!photos.value.length) {
    showToast('交付成功请至少上传 1 张现场照片', { type: 'error' })
    return
  }
  uni.showLoading({ title: '上传照片…', mask: true })
  let uploaded: string[]
  try {
    uploaded = await Promise.all(photos.value.map((path) => uploadImage(path)))
  } catch (e) {
    uni.hideLoading()
    showToast(e instanceof Error ? e.message : '照片上传失败', { type: 'error' })
    return
  }
  uni.hideLoading()
  if (await techDeliverSuccess(order.value.id, uploaded)) {
    goBackAfterSuccess('交付成功', 'done')
  } else {
    showToast('提交失败', { type: 'error' })
  }
}

async function deliverFail() {
  if (!order.value) return
  const ok = await showConfirm({
    title: '交回商家',
    content: '确认无法完成上门交付？订单将交回商家跟进，您这边任务结束。下一步需填写原因。',
    confirmText: '去填写原因',
    cancelText: '取消',
    tone: 'warn',
    icon: '!',
  })
  if (!ok) return
  uni.showModal({
    title: '退回原因',
    editable: true,
    placeholderText: '如：客户家中无人 / 地址有误',
    success: async (res) => {
      if (!res.confirm) return
      const reason = (res.content || '').trim()
      if (!reason) {
        showToast('请填写退回原因', { type: 'error' })
        return
      }
      if (!order.value) return
      if (await techDeliverFail(order.value.id, reason)) {
        goBackAfterSuccess('已交回商家', 'returned')
      } else {
        showToast('提交失败', { type: 'error' })
      }
    },
  })
}
</script>

<style scoped>
.card {
  padding: 28rpx 24rpx;
}
.title {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  margin-bottom: 14rpx;
  color: #122033;
}
.line {
  display: block;
  color: #5a6b80;
  font-size: 26rpx;
  margin-bottom: 10rpx;
}
.hint {
  margin: 20rpx 0;
  padding: 22rpx 24rpx;
  color: #6b7a90;
  font-size: 24rpx;
  line-height: 1.6;
}
.fail,
.photos {
  margin-top: 16rpx;
  padding: 22rpx 24rpx;
}
.fail-t,
.photos-t {
  display: block;
  font-size: 24rpx;
  font-weight: 700;
  color: #c62828;
  margin-bottom: 8rpx;
}
.photos-t {
  color: #00897b;
}
.fail-d {
  font-size: 26rpx;
  color: #5a6b80;
  line-height: 1.5;
}
.photo-row {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}
.photo {
  width: 160rpx;
  height: 160rpx;
  border-radius: 12rpx;
  background: #eef2f6;
}
.add {
  width: 160rpx;
  height: 160rpx;
  border-radius: 12rpx;
  border: 2rpx dashed #b7c4d4;
  color: #7a8699;
  font-size: 22rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}
.deliver {
  margin-top: 8rpx;
}
.btn {
  margin-bottom: 16rpx;
  height: 88rpx;
  line-height: 88rpx;
  border-radius: 18rpx;
  font-weight: 600;
  color: #fff;
}
.btn::after {
  border: none;
}
.btn.teal {
  background: linear-gradient(135deg, #26a69a, #00897b);
  box-shadow: 0 12rpx 28rpx rgba(0, 137, 123, 0.3);
}
.btn.danger {
  background: linear-gradient(135deg, #ef9a9a, #c62828);
  box-shadow: 0 12rpx 28rpx rgba(198, 40, 40, 0.28);
}
.done {
  text-align: center;
  color: #2e7d32;
  font-weight: 700;
  margin-top: 24rpx;
}
.fail-end {
  text-align: center;
  color: #c62828;
  font-weight: 700;
  margin-top: 24rpx;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding-top: 120rpx;
}
</style>
