import { computed, ref, watch, type Ref } from 'vue'

export function uniq(values: Array<string | undefined | null>) {
  return [...new Set(values.filter((v): v is string => Boolean(v)))]
}

export function includesKw(source: string | undefined, kw: string) {
  if (!kw) return true
  return (source || '').toLowerCase().includes(kw.toLowerCase())
}

/** 列表筛选后分页；筛选条件变化时请自行把 page 置 1 */
export function usePager<T>(getList: () => T[], defaultSize = 10) {
  const page = ref(1)
  const pageSize = ref(defaultSize)
  const filtered = computed(() => getList())
  const paged = computed(() => {
    const start = (page.value - 1) * pageSize.value
    return filtered.value.slice(start, start + pageSize.value)
  })

  watch(pageSize, () => {
    page.value = 1
  })

  watch(filtered, (list) => {
    const max = Math.max(1, Math.ceil(list.length / pageSize.value) || 1)
    if (page.value > max) page.value = max
  })

  function resetPage() {
    page.value = 1
  }

  return { page, pageSize, filtered, paged, resetPage }
}

export function bindReset(deps: Ref<unknown>[], resetPage: () => void) {
  watch(deps, resetPage)
}
