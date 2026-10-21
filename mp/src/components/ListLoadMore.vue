<template>
  <view v-if="total > 0" class="foot">
    <text v-if="loadingMore">加载中…</text>
    <text v-else-if="hasMore">{{ loadMoreText }}</text>
    <text v-else>{{ doneText }}</text>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  total: number
  shown: number
  hasMore: boolean
  loadingMore?: boolean
}>()

const loadMoreText = computed(() => `上拉加载更多（已显示 ${props.shown} / ${props.total}）`)
const doneText = computed(() => `已全部加载（共 ${props.total} 条）`)
</script>

<style scoped>
.foot {
  padding: 28rpx 16rpx 48rpx;
  text-align: center;
  font-size: 22rpx;
  color: #9aa3b2;
}
</style>
