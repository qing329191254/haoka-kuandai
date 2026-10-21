<template>
  <el-tag :type="STATUS_TAG_TYPE[status]" size="small">{{ ORDER_STATUS_LABEL[status] }}</el-tag>
</template>

<script setup lang="ts">
import { ORDER_STATUS_LABEL, STATUS_TAG_TYPE, type OrderStatus } from '@/types/order'

defineProps<{ status: OrderStatus }>()
</script>
