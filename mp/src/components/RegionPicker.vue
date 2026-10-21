<template>
  <!-- 用原生 multiSelector，避免 picker-view 滚动音效 -->
  <picker
    mode="multiSelector"
    :range="rangeLists"
    :value="indexes"
    @columnchange="onColumnChange"
    @change="onChange"
  >
    <slot />
  </picker>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import {
  chinaRegionTree,
  findRegionIndexes,
  selectionFromIndexes,
  type RegionSelection,
} from '@/utils/chinaRegions'

const props = defineProps<{
  value?: RegionSelection | null
}>()

const emit = defineEmits<{
  confirm: [RegionSelection]
}>()

const provinces = chinaRegionTree
const indexes = ref<[number, number, number]>([0, 0, 0])

const cities = computed(() => provinces[indexes.value[0]]?.children || [])
const districts = computed(() => cities.value[indexes.value[1]]?.children || [])

const rangeLists = computed(() => [
  provinces.map((p) => p.name),
  cities.value.map((c) => c.name),
  districts.value.map((d) => d.name),
])

function syncFromValue() {
  indexes.value = findRegionIndexes(provinces, props.value)
}

watch(
  () => props.value,
  () => syncFromValue(),
  { immediate: true, deep: true },
)

function onColumnChange(e: { detail: { column: number; value: number } }) {
  const column = e.detail.column
  const value = e.detail.value
  const next: [number, number, number] = [...indexes.value]
  next[column] = value
  if (column === 0) {
    next[1] = 0
    next[2] = 0
  } else if (column === 1) {
    next[2] = 0
  }
  const cityList = provinces[next[0]]?.children || []
  if (next[1] >= cityList.length) next[1] = 0
  const distList = cityList[next[1]]?.children || []
  if (next[2] >= distList.length) next[2] = 0
  indexes.value = next
}

function onChange(e: { detail: { value: number[] } }) {
  const v = e.detail.value || [0, 0, 0]
  const sel = selectionFromIndexes(provinces, Number(v[0]) || 0, Number(v[1]) || 0, Number(v[2]) || 0)
  if (!sel) return
  indexes.value = [Number(v[0]) || 0, Number(v[1]) || 0, Number(v[2]) || 0]
  emit('confirm', sel)
}
</script>
