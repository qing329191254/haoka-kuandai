<template>
  <view v-if="bootLoading" class="boot">
    <view class="spinner" />
    <text class="boot-t">加载中…</text>
  </view>
  <view v-else-if="refreshing" class="bar">
    <view class="spinner sm" />
    <text class="bar-t">刷新中…</text>
  </view>
</template>

<script setup lang="ts">
defineProps<{
  refreshing?: boolean
  bootLoading?: boolean
}>()
</script>

<style scoped>
.boot {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 120rpx 0 80rpx;
  gap: 20rpx;
}
.boot-t {
  font-size: 26rpx;
  color: #6b7a90;
}
.bar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  padding: 12rpx 0 8rpx;
}
.bar-t {
  font-size: 22rpx;
  color: #8a94a6;
}
.spinner {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  border: 5rpx solid rgba(30, 136, 229, 0.18);
  border-top-color: #1e88e5;
  animation: spin 0.75s linear infinite;
}
.spinner.sm {
  width: 28rpx;
  height: 28rpx;
  border-width: 4rpx;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
