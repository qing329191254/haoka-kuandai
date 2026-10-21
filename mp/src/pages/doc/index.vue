<template>
  <view class="page page-shell">
    <view v-if="loading" class="state">
      <text class="state-t">加载中…</text>
    </view>
    <view v-else-if="error && !sections.length" class="state">
      <text class="state-t">{{ error }}</text>
      <text class="retry" @click="load">重试</text>
    </view>
    <view v-else class="card surface">
      <view v-for="(sec, i) in sections" :key="i" class="sec">
        <text v-if="sec.heading" class="heading">{{ sec.heading }}</text>
        <text class="body">{{ sec.body }}</text>
      </view>
    </view>
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { request } from '@/api/http'
import { hideMpHomeButton } from '@/utils/hideHomeButton'

type DocSection = { heading: string; body: string }

const DOC_TITLES: Record<string, string> = {
  privacy: '隐私政策',
  agreement: '用户协议',
}

const docId = ref('privacy')
const sections = ref<DocSection[]>([])
const loading = ref(true)
const error = ref('')

onLoad((query) => {
  const id = String(query?.id || 'privacy')
  docId.value = id === 'agreement' ? 'agreement' : 'privacy'
  uni.setNavigationBarTitle({
    title: DOC_TITLES[docId.value] || '文档',
  })
  load()
})

onShow(() => {
  hideMpHomeButton()
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const data = await request<{
      title?: string
      sections?: { heading?: string; body?: string }[]
    }>({ url: `/api/content/docs/${docId.value}` })
    const list = (data.sections || [])
      .map((e) => ({
        heading: String(e.heading || ''),
        body: String(e.body || ''),
      }))
      .filter((e) => e.heading || e.body)
    sections.value = list
    if (data.title) {
      uni.setNavigationBarTitle({ title: data.title })
    }
    if (!list.length) error.value = '暂无内容'
  } catch (e) {
    error.value = e instanceof Error ? e.message : '加载失败，请稍后重试'
    sections.value = []
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.state {
  padding: 120rpx 40rpx;
  text-align: center;
}
.state-t {
  display: block;
  font-size: 28rpx;
  color: #6b7a90;
}
.retry {
  display: inline-block;
  margin-top: 28rpx;
  font-size: 28rpx;
  color: #1e88e5;
  font-weight: 600;
}
.card {
  padding: 8rpx 28rpx 36rpx;
}
.sec {
  padding: 28rpx 0;
  border-bottom: 1rpx solid #e8eef5;
}
.sec:last-child {
  border-bottom: none;
}
.heading {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
  margin-bottom: 14rpx;
  line-height: 1.4;
}
.body {
  display: block;
  font-size: 28rpx;
  color: #4a5568;
  line-height: 1.7;
  white-space: pre-wrap;
}
</style>
