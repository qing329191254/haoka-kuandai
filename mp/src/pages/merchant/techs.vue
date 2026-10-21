<template>
  <view class="page page-shell dense" v-if="session">
    <view class="toolbar">
      <text class="tip">本门店上门师傅，派单时从此列表选择</text>
      <button class="add btn-primary" size="mini" @click="goEdit()">新增师傅</button>
    </view>
    <ListRefreshBar :refreshing="refreshing" :boot-loading="bootLoading" />
    <view v-if="!bootLoading && !allList.length" class="empty surface">暂无师傅，请先新增</view>
    <view v-for="t in visible" v-show="!bootLoading" :key="t.id" class="card surface">
      <view class="row">
        <text class="name">{{ t.name }}</text>
        <text class="tag" :class="t.status">{{ t.status === 'active' ? '在岗' : '停用' }}</text>
      </view>
      <text class="meta">{{ t.phone }} · {{ t.district }}</text>
      <text class="meta">技能：{{ skillText(t.skills) }}</text>
      <view class="ops">
        <text class="op" @click="goEdit(t.id)">编辑</text>
        <text class="op danger" @click="onRemove(t.id, t.name)">删除</text>
      </view>
    </view>
    <ListLoadMore
      v-if="!bootLoading"
      :total="total"
      :shown="visible.length"
      :has-more="hasMore"
      :loading-more="loadingMore"
    />
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onReachBottom, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import ListLoadMore from '@/components/ListLoadMore.vue'
import ListRefreshBar from '@/components/ListRefreshBar.vue'
import { useListRefresh } from '@/composables/useListRefresh'
import { usePagedList } from '@/composables/usePagedList'
import { fetchTechnicians, removeTechnician } from '@/store/technicians'
import { TECH_SKILL_LABEL, type MpTechnician, type TechSkill } from '@/data/technicians'
import { showConfirm, showToast, withLoading } from '@/store/feedback'
import { requireRole, type MpSession } from '@/store/session'

const session = ref<MpSession | null>(null)
const allList = ref<MpTechnician[]>([])
const { refreshing, bootLoading, runRefresh } = useListRefresh()

async function reload() {
  session.value = requireRole('merchant')
  if (!session.value?.merchantId) return
  await runRefresh(allList.value.length > 0, async () => {
    try {
      allList.value = await fetchTechnicians()
    } catch {
      if (!allList.value.length) allList.value = []
    }
  })
}

onShow(reload)

const { visible, total, hasMore, loadingMore, loadMore } = usePagedList(allList, 12)

onReachBottom(() => {
  loadMore()
})

function skillText(skills: TechSkill[]) {
  return skills.map((s) => TECH_SKILL_LABEL[s] || s).join(' / ')
}

function goEdit(id?: string) {
  const q = id ? `?id=${id}` : ''
  uni.navigateTo({ url: `/pages/merchant/tech-edit${q}` })
}

async function onRemove(id: string, name: string) {
  const ok = await showConfirm({
    title: '删除师傅',
    content: `确定删除「${name}」？删除后无法用该手机号登录师傅端。`,
    confirmText: '删除',
    cancelText: '取消',
    tone: 'warn',
    icon: '×',
  })
  if (!ok) return
  await withLoading(async () => {
    await removeTechnician(id)
    await reload()
  }, '提交中…')
  showToast('已删除', { type: 'success' })
}
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20rpx;
  gap: 16rpx;
}
.tip {
  font-size: 24rpx;
  color: #6b7a90;
  flex: 1;
  line-height: 1.4;
}
.add {
  margin: 0;
  padding: 0 22rpx;
  height: 60rpx;
  line-height: 60rpx;
  font-size: 24rpx;
}
.empty {
  padding: 80rpx 24rpx;
  text-align: center;
  color: #9aa3b2;
  font-size: 26rpx;
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
.name {
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.tag {
  font-size: 22rpx;
  color: #2e7d32;
  background: rgba(46, 125, 50, 0.1);
  padding: 4rpx 14rpx;
  border-radius: 999rpx;
  font-weight: 600;
}
.tag.disabled {
  color: #7a8699;
  background: #eef1f5;
}
.meta {
  display: block;
  margin-top: 10rpx;
  font-size: 24rpx;
  color: #7a8699;
}
.ops {
  margin-top: 18rpx;
  display: flex;
  gap: 32rpx;
}
.op {
  font-size: 26rpx;
  color: #1e88e5;
  font-weight: 600;
}
.op.danger {
  color: #c62828;
}
</style>
