<template>
  <view class="toolbar" :class="accent">
    <view class="search surface">
      <text class="ico">⌕</text>
      <input
        class="input"
        type="text"
        confirm-type="search"
        :value="modelValue"
        :placeholder="placeholder"
        placeholder-class="ph"
        @input="onInput"
        @confirm="emit('search')"
      />
      <text v-if="modelValue" class="clear" @click="clear">清除</text>
    </view>

    <scroll-view v-if="chips.length" class="chips" scroll-x :show-scrollbar="false">
      <view class="chips-inner">
        <text
          v-for="c in chips"
          :key="c.value"
          :class="['chip', activeChip === c.value ? 'on' : '']"
          @click="emit('update:activeChip', c.value)"
        >
          {{ c.label }}
        </text>
      </view>
    </scroll-view>

    <view v-if="summary" class="summary">
      <text class="sum-t">{{ summary }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
export interface FilterChip {
  value: string
  label: string
}

withDefaults(
  defineProps<{
    modelValue: string
    placeholder?: string
    chips?: FilterChip[]
    activeChip?: string
    summary?: string
    accent?: 'blue' | 'teal'
  }>(),
  {
    placeholder: '搜单号 / 客户 / 手机 / 地址',
    chips: () => [],
    activeChip: 'all',
    summary: '',
    accent: 'blue',
  },
)

const emit = defineEmits<{
  'update:modelValue': [string]
  'update:activeChip': [string]
  search: []
}>()

function onInput(e: Event) {
  emit('update:modelValue', String((e as Event & { detail?: { value?: string } }).detail?.value || ''))
}

function clear() {
  emit('update:modelValue', '')
}
</script>

<style scoped>
.toolbar {
  margin: -20rpx -28rpx 16rpx;
  padding: 12rpx 28rpx 8rpx;
  position: sticky;
  top: 0;
  z-index: 20;
  background: linear-gradient(180deg, #d6e8fb 0%, rgba(233, 240, 248, 0.96) 70%, rgba(233, 240, 248, 0.88) 100%);
}
.toolbar.teal {
  background: linear-gradient(180deg, #d4ebe8 0%, rgba(233, 240, 248, 0.96) 70%, rgba(233, 240, 248, 0.88) 100%);
}
.search {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 0 22rpx;
  height: 76rpx;
}
.ico {
  color: #8a96a8;
  font-size: 30rpx;
  flex-shrink: 0;
}
.input {
  flex: 1;
  height: 76rpx;
  font-size: 28rpx;
  color: #122033;
}
.ph {
  color: #b0b8c4;
}
.clear {
  font-size: 24rpx;
  color: #1e88e5;
  font-weight: 600;
  padding: 8rpx 4rpx;
  flex-shrink: 0;
}
.toolbar.teal .clear {
  color: #00897b;
}
.chips {
  margin-top: 14rpx;
  white-space: nowrap;
}
.chips-inner {
  display: inline-flex;
  gap: 12rpx;
  padding-bottom: 4rpx;
}
.chip {
  display: inline-block;
  padding: 10rpx 22rpx;
  border-radius: 999rpx;
  font-size: 24rpx;
  color: #5a6b80;
  background: rgba(255, 255, 255, 0.88);
  border: 1rpx solid rgba(18, 56, 110, 0.08);
  font-weight: 600;
}
.chip.on {
  color: #fff;
  background: linear-gradient(135deg, #42a5f5, #1e88e5);
  border-color: transparent;
  box-shadow: 0 6rpx 16rpx rgba(30, 136, 229, 0.28);
}
.toolbar.teal .chip.on {
  background: linear-gradient(135deg, #26a69a, #00897b);
  box-shadow: 0 6rpx 16rpx rgba(0, 137, 123, 0.28);
}
.summary {
  margin-top: 12rpx;
  padding: 0 4rpx 4rpx;
}
.sum-t {
  font-size: 22rpx;
  color: #8a96a8;
}
</style>
