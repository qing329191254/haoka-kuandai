<template>
  <el-card>
    <el-radio-group v-model="group" style="margin-bottom: 12px">
      <el-radio-button v-for="(label, key) in ORDER_GROUP_LABEL" :key="key" :label="key" :value="key">{{ label }}</el-radio-button>
    </el-radio-group>

    <div class="toolbar">
      <el-select v-model="bizType" clearable placeholder="业务类型" style="width: 200px">
        <el-option v-for="(label, key) in BIZ_TYPE_LABEL" :key="key" :label="label" :value="key" />
      </el-select>
      <el-select v-model="status" clearable placeholder="状态" style="width: 160px">
        <el-option v-for="(label, key) in ORDER_STATUS_LABEL" :key="key" :label="label" :value="key" />
      </el-select>
      <el-select v-model="merchant" clearable placeholder="履约商家" style="width: 160px">
        <el-option v-for="m in store.merchants" :key="m.id" :label="m.name" :value="m.name" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="订单号 / 客户 / 手机号" style="width: 240px" />
    </div>

    <el-table :data="paged" stripe style="margin-top: 12px">
      <el-table-column prop="orderNo" label="订单号" width="160" />
      <el-table-column label="业务类型" width="150">
        <template #default="{ row }">{{ orderBizLabel(row) }}</template>
      </el-table-column>
      <el-table-column prop="productName" label="套餐 / 说明" min-width="160" />
      <el-table-column prop="customerName" label="客户" width="80" />
      <el-table-column prop="customerPhone" label="手机号" width="120" />
      <el-table-column label="来源" width="72">
        <template #default>
          <el-tag size="small" type="primary" effect="plain">App</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="merchantName" label="商家" width="130">
        <template #default="{ row }">{{ row.merchantName || '-' }}</template>
      </el-table-column>
      <el-table-column prop="technicianName" label="师傅" width="90">
        <template #default="{ row }">{{ row.technicianName || '-' }}</template>
      </el-table-column>
      <el-table-column label="状态" width="110">
        <template #default="{ row }">
          <StatusTag :status="row.status" />
        </template>
      </el-table-column>
      <el-table-column label="用户侧" width="100">
        <template #default="{ row }">{{ labelCStatus(row.status) }}</template>
      </el-table-column>
      <el-table-column prop="createdAt" label="提交时间" width="170" />
      <el-table-column label="操作" width="88" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="$router.push(`/orders/${row.id}`)">详情</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="filtered.length"
        :page-sizes="[10, 20, 50]"
        layout="total, sizes, prev, pager, next, jumper"
        background
      />
    </div>
  </el-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import StatusTag from '@/components/StatusTag.vue'
import { useAdminStore } from '@/stores/admin'
import {
  BIZ_TYPE_LABEL,
  ORDER_GROUP_LABEL,
  ORDER_STATUS_LABEL,
  labelCStatus,
  matchOrderGroup,
  orderBizLabel,
  type BizType,
  type OrderGroup,
  type OrderStatus,
} from '@/types/order'

const store = useAdminStore()
const group = ref<OrderGroup>('all')
const bizType = ref<BizType>()
const status = ref<OrderStatus>()
const merchant = ref<string>()
const keyword = ref('')
const page = ref(1)
const pageSize = ref(10)

const filtered = computed(() =>
  store.orders.filter((o) => {
    if (!matchOrderGroup(o.status, group.value)) return false
    if (bizType.value && o.bizType !== bizType.value) return false
    if (status.value && o.status !== status.value) return false
    if (merchant.value && o.merchantName !== merchant.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      return o.orderNo.includes(k) || o.customerName.includes(k) || o.customerPhone.includes(k)
    }
    return true
  }),
)

const paged = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})

watch([group, bizType, status, merchant, keyword, pageSize], () => {
  page.value = 1
})
</script>

<style scoped>
.toolbar {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
</style>
