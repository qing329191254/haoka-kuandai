<template>
  <!-- Toast -->
  <view v-if="toast.visible" class="fb-mask toast-mask" @click="hideToast">
    <view class="fb-card toast-card" :class="toast.type" @click.stop>
      <view class="fb-icon" :class="toast.type">
        <text class="fb-icon-t">{{ toastIcon }}</text>
      </view>
      <text class="fb-title">{{ toast.title }}</text>
      <text v-if="toast.subtitle" class="fb-sub">{{ toast.subtitle }}</text>
    </view>
  </view>

  <!-- Confirm -->
  <view v-if="confirm.visible" class="fb-mask" @click="onCancel">
    <view class="fb-card confirm-card" @click.stop>
      <view class="fb-icon" :class="confirm.tone">
        <text class="fb-icon-t">{{ confirm.icon }}</text>
      </view>
      <text class="fb-title">{{ confirm.title }}</text>
      <text v-if="confirm.content" class="fb-sub">{{ confirm.content }}</text>
      <view class="fb-actions">
        <button class="fb-btn ghost" @click="onCancel">{{ confirm.cancelText }}</button>
        <button class="fb-btn solid" :class="confirm.tone" @click="onOk">{{ confirm.confirmText }}</button>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { feedbackState, hideToast, resolveConfirm } from '@/store/feedback'

const { toast, confirm } = feedbackState()

const toastIcon = computed(() => {
  if (toast.type === 'success') return '✓'
  if (toast.type === 'error') return '!'
  return 'i'
})

function onCancel() {
  resolveConfirm(false)
}
function onOk() {
  resolveConfirm(true)
}
</script>

<style scoped>
.fb-mask {
  position: fixed;
  inset: 0;
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(8, 20, 40, 0.38);
  backdrop-filter: blur(4px);
  animation: fb-fade 0.2s ease-out;
}
.toast-mask {
  background: rgba(8, 20, 40, 0.28);
}
.fb-card {
  width: 520rpx;
  padding: 44rpx 36rpx 40rpx;
  border-radius: 32rpx;
  background:
    linear-gradient(160deg, rgba(255, 255, 255, 0.98) 0%, #f2f7ff 100%);
  border: 1rpx solid rgba(255, 255, 255, 0.9);
  box-shadow:
    0 28rpx 80rpx rgba(12, 48, 96, 0.22),
    0 0 0 1rpx rgba(30, 136, 229, 0.06) inset;
  display: flex;
  flex-direction: column;
  align-items: center;
  animation: fb-pop 0.3s cubic-bezier(0.22, 1, 0.36, 1);
}
.toast-card {
  width: 400rpx;
  padding: 40rpx 32rpx 36rpx;
}
.fb-icon {
  width: 92rpx;
  height: 92rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 22rpx;
  box-shadow: 0 12rpx 28rpx rgba(30, 136, 229, 0.28);
}
.fb-icon.success,
.fb-icon.primary {
  background: linear-gradient(145deg, #4fc3f7 0%, #1e88e5 100%);
}
.fb-icon.error,
.fb-icon.warn {
  background: linear-gradient(145deg, #ffb74d 0%, #ef6c00 100%);
  box-shadow: 0 12rpx 28rpx rgba(239, 108, 0, 0.28);
}
.fb-icon.info {
  background: linear-gradient(145deg, #90a4ae 0%, #546e7a 100%);
  box-shadow: 0 12rpx 28rpx rgba(84, 110, 122, 0.25);
}
.fb-icon-t {
  color: #fff;
  font-size: 52rpx;
  font-weight: 700;
  line-height: 1;
  transform: scale(1.05);
}
.fb-title {
  font-size: 34rpx;
  font-weight: 700;
  color: #122033;
  text-align: center;
}
.fb-sub {
  margin-top: 12rpx;
  font-size: 26rpx;
  color: #6b7a90;
  text-align: center;
  line-height: 1.5;
  max-width: 420rpx;
}
.fb-actions {
  margin-top: 36rpx;
  width: 100%;
  display: flex;
  gap: 18rpx;
}
.fb-btn {
  flex: 1;
  margin: 0;
  height: 84rpx;
  line-height: 84rpx;
  border-radius: 18rpx;
  font-size: 28rpx;
  font-weight: 600;
}
.fb-btn::after {
  border: none;
}
.fb-btn.ghost {
  background: #e8eef6;
  color: #4a5d78;
}
.fb-btn.solid.primary {
  background: linear-gradient(135deg, #42a5f5, #1e88e5);
  color: #fff;
  box-shadow: 0 10rpx 24rpx rgba(30, 136, 229, 0.35);
}
.fb-btn.solid.warn {
  background: linear-gradient(135deg, #ff9800, #ef6c00);
  color: #fff;
  box-shadow: 0 10rpx 24rpx rgba(239, 108, 0, 0.32);
}
@keyframes fb-fade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
@keyframes fb-pop {
  from {
    opacity: 0;
    transform: scale(0.9) translateY(16rpx);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}
</style>
