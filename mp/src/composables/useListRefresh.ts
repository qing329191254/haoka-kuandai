import { ref } from 'vue'

/**
 * 列表刷新态：有缓存 → 顶部「刷新中」；无缓存 → 首屏加载。
 */
export function useListRefresh() {
  const refreshing = ref(false)
  const bootLoading = ref(false)

  async function runRefresh(hasCache: boolean, fn: () => Promise<void>) {
    if (hasCache) refreshing.value = true
    else bootLoading.value = true
    try {
      await fn()
    } finally {
      refreshing.value = false
      bootLoading.value = false
    }
  }

  return { refreshing, bootLoading, runRefresh }
}
