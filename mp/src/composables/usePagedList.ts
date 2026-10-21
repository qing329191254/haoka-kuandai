import { computed, ref, watch, type Ref, type ComputedRef } from 'vue'

type Source<T> = Ref<T[]> | ComputedRef<T[]>

/**
 * 列表按需渲染：先展示一页，触底再追加，避免一次挂载过多节点。
 */
export function usePagedList<T>(source: Source<T>, pageSize = 15) {
  const visibleCount = ref(pageSize)

  const total = computed(() => source.value.length)
  const visible = computed(() => source.value.slice(0, visibleCount.value))
  const hasMore = computed(() => visibleCount.value < source.value.length)
  const loadingMore = ref(false)

function reset() {
  visibleCount.value = pageSize
}

function loadMore() {
  if (!hasMore.value || loadingMore.value) return false
  loadingMore.value = true
  setTimeout(() => {
    visibleCount.value = Math.min(visibleCount.value + pageSize, source.value.length)
    loadingMore.value = false
  }, 16)
  return true
}

watch(
  () => [source.value.length, source.value[0]] as const,
  () => {
    visibleCount.value = pageSize
  },
)

  return {
    visible,
    total,
    hasMore,
    loadingMore,
    loadMore,
    reset,
    pageSize,
  }
}
