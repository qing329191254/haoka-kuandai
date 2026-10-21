<template>
  <el-cascader
    class="region-cascader"
    :model-value="path"
    :options="options"
    :props="cascaderProps"
    :placeholder="placeholder"
    clearable
    filterable
    :show-all-levels="true"
    separator=" / "
    :teleported="true"
    popper-class="region-cascader-popper"
    style="width: 100%"
    @update:model-value="onChange"
  />
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { loadChinaRegions, type RegionNode } from '@/data/chinaRegions'

const props = withDefaults(
  defineProps<{
    province?: string
    city?: string
    district?: string
    placeholder?: string
    /** 仅选到地级市（商品上架绑定城市） */
    cityOnly?: boolean
    /** 允许点选中间级（押金规则可选「全省」） */
    checkStrictly?: boolean
  }>(),
  {
    province: '',
    city: '',
    district: '',
    placeholder: '请选择省 / 市 / 区',
    cityOnly: false,
    checkStrictly: false,
  },
)

const emit = defineEmits<{
  change: [payload: { province: string; city: string; district: string }]
}>()

const rawOptions = ref<RegionNode[]>([])
const options = computed(() => {
  if (!props.cityOnly) return rawOptions.value
  return rawOptions.value.map((p) => ({
    name: p.name,
    children: (p.children || []).map((c) => ({ name: c.name })),
  }))
})
const cascaderProps = computed(() => ({
  label: 'name',
  value: 'name',
  children: 'children',
  expandTrigger: 'hover' as const,
  checkStrictly: props.checkStrictly,
}))

const path = computed(() => {
  if (!props.province) return []
  if (props.cityOnly) return [props.province, props.city].filter(Boolean)
  return [props.province, props.city, props.district].filter(Boolean)
})

onMounted(async () => {
  rawOptions.value = await loadChinaRegions()
})

function onChange(val: string[] | null) {
  const [province = '', city = '', district = ''] = val || []
  emit('change', { province, city, district: props.cityOnly ? '' : district })
}
</script>

<style scoped>
.region-cascader :deep(.el-input__wrapper) {
  min-height: 40px;
  border-radius: 10px;
  box-shadow: 0 0 0 1px rgba(26, 115, 232, 0.14) inset;
  background: linear-gradient(180deg, #fff 0%, #f7fafd 100%);
}
.region-cascader :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 1px var(--el-color-primary) inset !important;
}
.region-cascader :deep(.el-input__inner) {
  font-size: 14px;
  letter-spacing: 0.01em;
}
</style>
