<template>
  <view class="page page-shell dense">
    <view v-if="stage !== 'entry'" class="tabs surface">
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
      accent="blue"
      @update:model-value="onFilterChange"
      @update:active-chip="onFilterChange"
    />

    <ListRefreshBar :refreshing="refreshing" :boot-loading="bootLoading" />

    <view v-for="o in visible" v-show="!bootLoading" :key="o.id" class="card surface" @click="open(o)">
      <view class="row">
        <text class="biz">{{ orderBizLabel(o) }}</text>
        <text class="status">{{ STATUS_LABEL[o.status] }}</text>
      </view>
      <text class="name">{{ o.productName }}</text>
      <text class="meta">{{ o.customerName }} · {{ o.customerPhone }}</text>
      <text class="meta">{{ o.address }}</text>
      <text v-if="o.followUpReason" class="meta warn">{{ o.followUpReason }}</text>
      <text v-if="o.nextFollowUpAt" class="meta">{{ nextContactLabel(o.nextFollowUpAt) }}</text>
      <text class="no">{{ o.orderNo }}</text>
      <view class="actions" @click.stop>
        <!-- 订单录入 -->
        <button v-if="stage === 'entry' && o.status === 'listed'" size="mini" class="btn primary" @click="accept(o.id)">
          接单
        </button>

        <!-- 订单办理 -->
        <template v-if="stage === 'process'">
          <button
            v-if="canRemoteDone(o)"
            size="mini"
            class="btn primary"
            @click="remoteDone(o.id)"
          >
            办结
          </button>
          <button
            v-if="canMarkDispatch(o)"
            size="mini"
            class="btn warn"
            @click="markDispatch(o.id)"
          >
            需上门
          </button>
          <button
            v-if="canFollowUp(o)"
            size="mini"
            class="btn ghost"
            @click="toFollowUp(o.id)"
          >
            跟进
          </button>
          <button
            v-if="o.status === 'follow_up' || o.status === 'failed'"
            size="mini"
            class="btn primary"
            @click="resume(o.id)"
          >
            恢复
          </button>
          <button v-if="canBossPc(o)" size="mini" class="btn primary" @click="toBossPc(o.id)">
            {{ bossPcLabel(o) }}
          </button>
        </template>

        <!-- 派单上门 -->
        <template v-if="stage === 'dispatch'">
          <button
            v-if="o.status === 'merchant_accepted' && o.needsDispatch"
            size="mini"
            class="btn warn"
            @click="toDispatch(o.id)"
          >
            派单给师傅
          </button>
        </template>
      </view>
    </view>

    <view v-if="!bootLoading && !filtered.length" class="empty">{{ emptyText }}</view>
    <ListLoadMore
      v-if="!bootLoading"
      :total="total"
      :shown="visible.length"
      :has-more="hasMore"
      :loading-more="loadingMore"
    />
    <BackToTop :visible="showTop" accent="blue" />
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { onLoad, onPageScroll, onReachBottom, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import BackToTop from '@/components/BackToTop.vue'
import ListLoadMore from '@/components/ListLoadMore.vue'
import ListRefreshBar from '@/components/ListRefreshBar.vue'
import OrderListToolbar, { type FilterChip } from '@/components/OrderListToolbar.vue'
import { useListRefresh } from '@/composables/useListRefresh'
import { usePagedList } from '@/composables/usePagedList'
import { STATUS_LABEL, orderBizLabel, skipTechDispatch, type BizType, type MpOrder } from '@/types/order'
import { showConfirm, showToast, withLoading } from '@/store/feedback'
import {
  acceptByMerchant,
  listOrders,
  merchantCompleteRemote,
  merchantMarkNeedsDispatch,
  merchantResumeProcessing,
  refreshOrders,
} from '@/store/orders'
import { requireRole } from '@/store/session'
import { filterOrders, sortOrdersByTime } from '@/utils/orderQuery'
import {
  orderInStage,
  parseWorkStage,
  stageTabCounts,
  WORK_STAGE_TITLE,
  type WorkStage,
} from '@/utils/workStage'

type TabKey = 'pending' | 'mine' | 'follow'

const bizChips: FilterChip[] = [
  { value: 'all', label: '全部业务' },
  { value: 'haoka', label: '号卡' },
  { value: 'contract_phone', label: '合约机' },
  { value: 'broadband_naked', label: '裸宽' },
  { value: 'broadband_new_card', label: '融合新开卡' },
  { value: 'broadband_no_card', label: '融合线上' },
  { value: 'wifi', label: 'WIFI 设备' },
  { value: 'cpe', label: 'CPE' },
  { value: 'stock', label: '存量业务' },
]

const stage = ref<WorkStage>('entry')
const tab = ref<TabKey>('pending')
const keyword = ref('')
const bizChip = ref('all')
const orders = ref<MpOrder[]>(sortOrdersByTime(listOrders()))
const showTop = ref(false)
const { refreshing, bootLoading, runRefresh } = useListRefresh()

const stageTitle = computed(() => WORK_STAGE_TITLE[stage.value])

const tabs = computed((): { key: TabKey; label: string }[] => {
  if (stage.value === 'process') {
    return [
      { key: 'mine', label: '办理中' },
      { key: 'follow', label: '跟进中' },
    ]
  }
  return [
    { key: 'pending', label: '待派单' },
    { key: 'mine', label: '上门中' },
  ]
})

async function refresh() {
  if (!requireRole('merchant')) return
  await runRefresh(orders.value.length > 0 || listOrders().length > 0, async () => {
    await refreshOrders()
    orders.value = sortOrdersByTime(listOrders())
  })
}

onLoad((q) => {
  stage.value = parseWorkStage(String(q?.stage || ''))
  const t = String(q?.tab || '')
  if (t === 'pending' || t === 'mine' || t === 'follow') tab.value = t
  else tab.value = stage.value === 'process' ? 'mine' : 'pending'
  uni.setNavigationBarTitle({ title: WORK_STAGE_TITLE[stage.value] })
})

onShow(refresh)

const stageOrders = computed(() => orders.value.filter((o) => orderInStage(o, stage.value)))

const tabCounts = computed(() => stageTabCounts(stageOrders.value, stage.value))

const scoped = computed(() => {
  const list = stageOrders.value
  if (stage.value === 'entry') return list
  if (stage.value === 'process') {
    if (tab.value === 'follow') {
      return list.filter((o) => o.status === 'follow_up' || o.status === 'failed')
    }
    return list.filter((o) => o.status !== 'follow_up' && o.status !== 'failed')
  }
  if (tab.value === 'pending') {
    return list.filter((o) => o.status === 'merchant_accepted' && o.needsDispatch)
  }
  return list.filter((o) => o.status !== 'merchant_accepted' || !o.needsDispatch)
})

const filtered = computed(() =>
  filterOrders(scoped.value, {
    keyword: keyword.value,
    bizType: bizChip.value as BizType | 'all',
    status: 'all',
  }),
)

const summaryText = computed(() => {
  const n = filtered.value.length
  if (keyword.value.trim() || bizChip.value !== 'all') return `筛选结果 ${n} 条`
  if (stage.value === 'entry') return `待接单 · ${n} 条`
  return `${stageTitle.value} · ${n} 条`
})

const emptyText = computed(() => {
  if (keyword.value.trim() || bizChip.value !== 'all') return '没有符合条件的订单'
  if (stage.value === 'entry' || stage.value === 'process') return '暂无订单'
  return tab.value === 'pending' ? '暂无待派单订单' : '暂无上门中订单'
})

const { visible, total, hasMore, loadingMore, loadMore, reset } = usePagedList(filtered, 12)

function onFilterChange() {
  reset()
}

function switchTab(t: TabKey) {
  tab.value = t
  reset()
}

watch([filtered, stage], () => reset())

onReachBottom(() => {
  loadMore()
})

onPageScroll((e) => {
  showTop.value = e.scrollTop > 420
})

function canBossPc(o: MpOrder) {
  if (!skipTechDispatch(o.bizType)) return false
  return ['merchant_accepted', 'boss_opened', 'installing'].includes(o.status)
}

function canRemoteComplete(bizType: BizType) {
  return bizType === 'haoka' || bizType === 'contract_phone' || bizType === 'stock'
}

function canRemoteDone(o: MpOrder) {
  return o.status === 'merchant_accepted' && !o.needsDispatch && canRemoteComplete(o.bizType)
}

function canMarkDispatch(o: MpOrder) {
  if (skipTechDispatch(o.bizType)) return false
  return ['merchant_accepted', 'follow_up', 'failed'].includes(o.status)
}

function canFollowUp(o: MpOrder) {
  return ['merchant_accepted', 'follow_up', 'failed'].includes(o.status)
}

function bossPcLabel(o: MpOrder) {
  if (o.status === 'boss_opened' || o.status === 'installing') return '确认装机'
  if (o.bizType === 'broadband_naked') return '开始办理'
  return '电脑端开户'
}

async function accept(id: string) {
  const ok = await withLoading(() => acceptByMerchant(id), '提交中…')
  if (ok) {
    showToast('接单成功', { type: 'success' })
    refresh()
  } else {
    showToast('接单失败', { type: 'error' })
  }
}

async function remoteDone(id: string) {
  const ok = await showConfirm({
    title: '办结',
    content: '确认订单已办理完成？',
    confirmText: '确认',
    tone: 'primary',
  })
  if (!ok) return
  if (await withLoading(() => merchantCompleteRemote(id), '提交中…')) {
    showToast('已办结', { type: 'success' })
    refresh()
  } else {
    showToast('操作失败', { type: 'error' })
  }
}

async function markDispatch(id: string) {
  const ok = await showConfirm({
    title: '需上门',
    content: '确认该订单需上门办理？',
    confirmText: '确认',
    tone: 'warn',
  })
  if (!ok) return
  if (await withLoading(() => merchantMarkNeedsDispatch(id), '提交中…')) {
    showToast('已提交', { type: 'success' })
    refresh()
  } else {
    showToast('操作失败', { type: 'error' })
  }
}

async function resume(id: string) {
  if (await withLoading(() => merchantResumeProcessing(id), '提交中…')) {
    showToast('已恢复', { type: 'success' })
    refresh()
  } else {
    showToast('操作失败', { type: 'error' })
  }
}

function toFollowUp(id: string) {
  uni.navigateTo({ url: `/pages/merchant/follow-up?id=${id}` })
}

function toDispatch(id: string) {
  uni.navigateTo({ url: `/pages/merchant/dispatch?id=${id}` })
}

function toBossPc(id: string) {
  uni.navigateTo({ url: `/pages/merchant/boss-pc?id=${id}` })
}

function open(o: MpOrder) {
  uni.navigateTo({ url: `/pages/order/detail?id=${o.id}` })
}

function nextContactLabel(at: string) {
  return `下次联系：${at}`
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
  background: linear-gradient(135deg, #42a5f5, #1e88e5);
  color: #fff;
  box-shadow: 0 8rpx 20rpx rgba(30, 136, 229, 0.28);
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
  font-size: 26rpx;
}
.status {
  color: #1e88e5;
  font-size: 24rpx;
  font-weight: 600;
  background: rgba(30, 136, 229, 0.1);
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
.meta.warn {
  color: #ef6c00;
}
.no {
  display: block;
  margin-top: 8rpx;
  font-size: 22rpx;
  color: #a0aab8;
}
.actions {
  margin-top: 18rpx;
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}
.btn {
  margin: 0;
  font-size: 24rpx;
  border-radius: 12rpx;
  font-weight: 600;
}
.btn::after {
  border: none;
}
.btn.primary {
  background: linear-gradient(135deg, #42a5f5, #1e88e5);
  color: #fff;
}
.btn.warn {
  background: linear-gradient(135deg, #ffb74d, #ef6c00);
  color: #fff;
}
.btn.ghost {
  background: #f0f4f8;
  color: #5a6b80;
}
.empty {
  text-align: center;
  color: #9aa3b2;
  padding: 100rpx 0;
  font-size: 26rpx;
}
</style>
