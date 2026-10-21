<template>
  <view class="page page-shell dense">
    <view class="tabs surface">
      <text
        v-for="t in tabs"
        :key="t.key"
        :class="['tab', tab === t.key ? 'on' : '']"
        @click="switchTab(t.key)"
      >
        {{ t.label }}
        <text v-if="tabCounts[t.key]" class="cnt">{{ tabCounts[t.key] }}</text>
      </text>
    </view>

    <OrderListToolbar
      v-model="keyword"
      v-model:active-chip="bizChip"
      :chips="bizChips"
      :summary="summaryText"
      accent="teal"
      placeholder="搜单号 / 客户 / 手机 / 地址"
      @update:model-value="onFilterChange"
      @update:active-chip="onFilterChange"
    />

    <view v-for="o in visible" :key="o.id" class="card surface" @click="go(o.id)">
      <view class="row">
        <text class="biz">{{ orderBizLabel(o) }}</text>
        <text class="status">{{ STATUS_LABEL[o.status] }}</text>
      </view>
      <text class="name">{{ o.productName }}</text>
      <text class="meta">{{ o.customerName }} · {{ o.customerPhone }}</text>
      <text class="meta">{{ o.address }}</text>
      <text class="no">{{ o.orderNo }}</text>
    </view>

    <view v-if="!filtered.length" class="empty">{{ emptyText }}</view>
    <ListLoadMore
      :total="total"
      :shown="visible.length"
      :has-more="hasMore"
      :loading-more="loadingMore"
    />
    <BackToTop :visible="showTop" accent="teal" />
  </view>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { onLoad, onPageScroll, onReachBottom, onShow } from '@dcloudio/uni-app'
import BackToTop from '@/components/BackToTop.vue'
import ListLoadMore from '@/components/ListLoadMore.vue'
import OrderListToolbar, { type FilterChip } from '@/components/OrderListToolbar.vue'
import { usePagedList } from '@/composables/usePagedList'
import { STATUS_LABEL, orderBizLabel, type MpOrder, type OrderStatus } from '@/types/order'
import { listOrders, refreshOrders } from '@/store/orders'
import { requireRole } from '@/store/session'
import { filterOrders, sortOrdersByTime } from '@/utils/orderQuery'

type TabKey = 'todo' | 'serving' | 'done' | 'returned'

const tabs: { key: TabKey; label: string }[] = [
  { key: 'todo', label: '待上门' },
  { key: 'serving', label: '服务中' },
  { key: 'done', label: '已完成' },
  { key: 'returned', label: '已退回' },
]

const bizChips: FilterChip[] = [
  { value: 'all', label: '全部业务' },
  { value: 'haoka', label: '号卡' },
  { value: 'contract_phone', label: '合约机' },
  { value: 'broadband_new_card', label: '融合宽带' },
  { value: 'wifi', label: 'WIFI 设备' },
  { value: 'cpe', label: 'CPE' },
  { value: 'stock:st1', label: '宽带续费' },
  { value: 'stock:st2', label: '套餐升档' },
  { value: 'stock:st3', label: 'IPTV' },
]

const TAB_STATUS: Record<TabKey, OrderStatus[]> = {
  todo: ['dispatched'],
  serving: ['tech_accepted', 'boss_opened', 'installing'],
  done: ['done'],
  returned: ['failed', 'follow_up'],
}

const tab = ref<TabKey>('todo')
const keyword = ref('')
const bizChip = ref('all')
const orders = ref<MpOrder[]>([])
const showTop = ref(false)

async function refresh() {
  if (!requireRole('technician')) return
  await refreshOrders()
  orders.value = sortOrdersByTime(listOrders())
  const prefer = uni.getStorageSync('tech_tasks_prefer_tab') as TabKey | 'failed' | ''
  if (prefer === 'todo' || prefer === 'serving' || prefer === 'done' || prefer === 'returned' || prefer === 'failed') {
    tab.value = prefer === 'failed' ? 'returned' : prefer
    uni.removeStorageSync('tech_tasks_prefer_tab')
  }
}

onLoad((q) => {
  const t = (q?.tab as TabKey | 'failed') || ''
  if (t === 'todo' || t === 'serving' || t === 'done' || t === 'returned' || t === 'failed') {
    tab.value = t === 'failed' ? 'returned' : t
  }
  const biz = String(q?.biz || '')
  if (biz) bizChip.value = biz
})

onShow(refresh)

const tabCounts = computed(() => ({
  todo: orders.value.filter((o) => TAB_STATUS.todo.includes(o.status)).length,
  serving: orders.value.filter((o) => TAB_STATUS.serving.includes(o.status)).length,
  done: orders.value.filter((o) => TAB_STATUS.done.includes(o.status)).length,
  returned: orders.value.filter((o) => o.status === 'failed' || o.status === 'follow_up').length,
}))

const filtered = computed(() =>
  filterOrders(orders.value, {
    keyword: keyword.value,
    groupKey: bizChip.value,
    statuses: TAB_STATUS[tab.value],
  }),
)

const summaryText = computed(() => {
  const n = filtered.value.length
  if (keyword.value.trim() || bizChip.value !== 'all') return `筛选结果 ${n} 条`
  return `本页 ${n} 条 · 上拉加载更多`
})

const emptyText = computed(() => {
  if (keyword.value.trim() || bizChip.value !== 'all') return '没有符合条件的任务'
  if (tab.value === 'todo') return '暂无待上门任务'
  if (tab.value === 'done') return '暂无已完成任务'
  if (tab.value === 'returned') return '暂无已退回任务'
  return '暂无服务中任务'
})

const { visible, total, hasMore, loadingMore, loadMore, reset } = usePagedList(filtered, 12)

function onFilterChange() {
  reset()
}

function switchTab(t: TabKey) {
  tab.value = t
  reset()
}

watch(filtered, () => reset())

onReachBottom(() => {
  loadMore()
})

onPageScroll((e) => {
  showTop.value = e.scrollTop > 420
})

function go(id: string) {
  uni.navigateTo({ url: `/pages/tech/detail?id=${id}` })
}
</script>

<style scoped>
.tabs {
  display: flex;
  padding: 8rpx;
  margin-bottom: 16rpx;
}
.tab {
  flex: 1;
  text-align: center;
  padding: 16rpx 0;
  border-radius: 16rpx;
  color: #6b7a90;
  font-size: 26rpx;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6rpx;
}
.tab.on {
  background: linear-gradient(135deg, #26a69a, #00897b);
  color: #fff;
  box-shadow: 0 8rpx 20rpx rgba(0, 137, 123, 0.28);
}
.cnt {
  font-size: 20rpx;
  opacity: 0.9;
  font-weight: 700;
}
.tab.on .cnt {
  background: rgba(255, 255, 255, 0.22);
  padding: 0 8rpx;
  border-radius: 999rpx;
}
.card {
  padding: 26rpx 24rpx;
  margin-bottom: 16rpx;
}
.row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.biz {
  font-weight: 700;
  color: #122033;
}
.status {
  color: #00897b;
  font-size: 24rpx;
  font-weight: 600;
  background: rgba(0, 137, 123, 0.1);
  padding: 4rpx 14rpx;
  border-radius: 999rpx;
}
.name {
  display: block;
  margin-top: 14rpx;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.meta {
  display: block;
  margin-top: 8rpx;
  color: #7a8699;
  font-size: 24rpx;
}
.no {
  display: block;
  margin-top: 8rpx;
  font-size: 22rpx;
  color: #a0aab8;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding: 100rpx 0;
}
</style>
