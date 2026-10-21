<template>
  <view v-if="visible" class="fab" :class="accent" @click="toTop">
    <text class="t">顶</text>
  </view>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    visible?: boolean
    accent?: 'blue' | 'teal'
  }>(),
  { visible: false, accent: 'blue' },
)

function toTop() {
  uni.pageScrollTo({ scrollTop: 0, duration: 280 })
}
</script>

<style scoped>
.fab {
  position: fixed;
  right: 28rpx;
  bottom: calc(48rpx + env(safe-area-inset-bottom));
  width: 84rpx;
  height: 84rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 40;
  background: linear-gradient(145deg, #42a5f5, #1e88e5);
  box-shadow: 0 12rpx 28rpx rgba(30, 136, 229, 0.4);
}
.fab.teal {
  background: linear-gradient(145deg, #26a69a, #00897b);
  box-shadow: 0 12rpx 28rpx rgba(0, 137, 123, 0.4);
}
.t {
  color: #fff;
  font-size: 28rpx;
  font-weight: 700;
}
</style>
