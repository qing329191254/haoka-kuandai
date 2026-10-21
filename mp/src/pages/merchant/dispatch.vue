<template>
  <view class="page page-shell dense" v-if="order">
    <view class="info surface">
      <text class="title">{{ order.productName }}</text>
      <text class="line">客户：{{ order.customerName }} {{ order.customerPhone }}</text>
      <text class="line">地址：{{ order.address }}</text>
      <text class="line">状态：{{ STATUS_LABEL[order.status] }}</text>
    </view>

    <text class="section">选择上门师傅</text>
    <view v-if="!techs.length" class="empty-tech surface">
      本店暂无师傅，请先在「上门师傅」中新增
      <text class="link" @click="goTechs">去新增</text>
    </view>
    <radio-group v-else @change="onPick">
      <label v-for="t in visible" :key="t.id" class="tech surface">
        <radio :value="t.id" :checked="picked === t.id" color="#1e88e5" />
        <text>{{ t.name }}（{{ t.phone }}）</text>
      </label>
    </radio-group>

    <ListLoadMore
      v-if="techs.length"
      :total="total"
      :shown="visible.length"
      :has-more="hasMore"
      :loading-more="loadingMore"
    />

    <button
      class="btn btn-primary"
      :disabled="!picked || order.status !== 'merchant_accepted' || !order.needsDispatch"
      @click="submit"
    >
      确认派单
    </button>
    <AppFeedback />
  </view>
  <view v-else class="page page-shell empty">订单不存在</view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onReachBottom, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import ListLoadMore from '@/components/ListLoadMore.vue'
import { usePagedList } from '@/composables/usePagedList'
import { STATUS_LABEL, type MpOrder } from '@/types/order'
import { showToast } from '@/store/feedback'
import { dispatchToTech, fetchOrder } from '@/store/orders'
import { fetchTechnicians } from '@/store/technicians'
import { requireRole, type MpSession } from '@/store/session'

const orderId = ref('')
const order = ref<MpOrder>()
const session = ref<MpSession | null>(null)
const techs = ref<{ id: string; name: string; phone: string; status?: string }[]>([])
const picked = ref('')

const { visible, total, hasMore, loadingMore, loadMore, reset } = usePagedList(techs, 15)

async function reload() {
  session.value = requireRole('merchant')
  if (!session.value) return
  order.value = await fetchOrder(orderId.value)
  try {
    techs.value = (await fetchTechnicians()).filter((t) => t.status === 'active')
  } catch {
    techs.value = []
  }
  reset()
}

onLoad((q) => {
  orderId.value = String(q?.id || '')
})

onShow(reload)

onReachBottom(() => {
  loadMore()
})

function onPick(e: { detail: { value: string } }) {
  picked.value = e.detail.value
}

async function submit() {
  if (!order.value || !picked.value) return
  const tech = techs.value.find((t) => t.id === picked.value)
  if (await dispatchToTech(order.value.id, tech?.name || '', picked.value)) {
    showToast('派单成功', { type: 'success', duration: 800 })
    setTimeout(() => uni.navigateBack(), 800)
  } else {
    showToast('派单失败（需已确认上门且处于待派单）', { type: 'error' })
  }
}

function goTechs() {
  uni.navigateTo({ url: '/pages/merchant/techs' })
}
</script>

<style scoped>
.info {
  padding: 28rpx 24rpx;
  margin-bottom: 24rpx;
}
.title {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #122033;
  margin-bottom: 12rpx;
}
.line {
  display: block;
  margin-top: 8rpx;
  color: #6b7a90;
  font-size: 26rpx;
}
.section {
  display: block;
  margin-bottom: 14rpx;
  font-weight: 700;
  color: #5a6b80;
  font-size: 26rpx;
}
.tech {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 24rpx;
  margin-bottom: 12rpx;
  font-size: 28rpx;
  color: #122033;
}
.btn {
  margin-top: 16rpx;
  height: 88rpx;
  line-height: 88rpx;
}
.btn[disabled] {
  opacity: 0.5;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding-top: 120rpx;
}
.empty-tech {
  padding: 24rpx;
  font-size: 26rpx;
  line-height: 1.5;
  color: #8d6e63;
  background: linear-gradient(135deg, #fff8e1, #fff3cd) !important;
}
.empty-tech .link {
  margin-left: 12rpx;
  color: #1e88e5;
  font-weight: 600;
}
</style>
