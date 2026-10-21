<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>号卡出入库</span>
        <div>
          <el-button v-if="can('stock:in')" type="success" @click="open('in')">入库</el-button>
          <el-button v-if="can('stock:out')" type="warning" @click="open('out')">出库</el-button>
        </div>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="type" clearable placeholder="出入类型" style="width: 140px">
        <el-option label="入库" value="in" />
        <el-option label="出库" value="out" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="产品 / SKU / 订单号 / 操作人" style="width: 280px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column label="类型" width="90">
        <template #default="{ row }">
          <el-tag :type="row.type === 'in' ? 'success' : 'warning'" size="small">
            {{ row.type === 'in' ? '入库' : '出库' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="productName" label="产品" min-width="180" />
      <el-table-column prop="sku" label="SKU" width="120" />
      <el-table-column prop="qty" label="数量" width="80" />
      <el-table-column prop="orderNo" label="关联订单" width="160">
        <template #default="{ row }">
          <el-button v-if="row.orderNo" link type="primary" @click="goOrder(row.orderNo)">{{ row.orderNo }}</el-button>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column prop="operator" label="操作人" width="110" />
      <el-table-column prop="remark" label="备注" min-width="140">
        <template #default="{ row }">{{ row.remark || '-' }}</template>
      </el-table-column>
      <el-table-column prop="createdAt" label="时间" width="170" />
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.type === 'in' ? '入库' : '出库'" width="480px">
      <el-form :model="form" label-width="88px">
        <el-form-item label="库存品">
          <el-select v-model="form.warehouseId" style="width: 100%">
            <el-option
              v-for="w in store.warehouse"
              :key="w.id"
              :label="`${w.productName} · ${w.sku}（库存 ${w.stock}）`"
              :value="w.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="form.qty" :min="1" />
        </el-form-item>
        <el-form-item v-if="form.type === 'out'" label="关联订单">
          <el-select v-model="form.orderNo" filterable clearable placeholder="选择号卡订单" style="width: 100%">
            <el-option
              v-for="o in store.orders.filter((x) => x.bizType === 'haoka' && x.status !== 'cancelled')"
              :key="o.id"
              :label="`${o.orderNo} · ${o.productName}`"
              :value="o.orderNo"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.remark" type="textarea" resize="none" :rows="2" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false">取消</el-button>
        <el-button type="primary" @click="save">确认</el-button>
      </template>
    </el-dialog>
  </el-card>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import type { StockType } from '@/types/stock'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const router = useRouter()
const { can, current } = usePermission()
const type = ref<StockType>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  store.stockRecords.filter((r) => {
    if (type.value && r.type !== type.value) return false
    const k = keyword.value.trim()
    return includesKw(r.productName, k) || includesKw(r.sku, k) || includesKw(r.orderNo, k) || includesKw(r.operator, k)
  }),
)
watch([type, keyword], () => {
  page.value = 1
})
const visible = ref(false)
const form = reactive({
  type: 'in' as StockType,
  warehouseId: '',
  qty: 1,
  orderNo: '',
  remark: '',
})

function open(type: StockType) {
  form.type = type
  form.warehouseId = store.warehouse[0]?.id || ''
  form.qty = 1
  form.orderNo = ''
  form.remark = type === 'out' ? '号卡订单出库' : '号卡到货入库'
  visible.value = true
}

function save() {
  void (async () => {
    const err = await withLoading(
      () =>
        store.addStock({
          type: form.type,
          warehouseId: form.warehouseId,
          qty: form.qty,
          orderNo: form.orderNo || undefined,
          operator: current.value?.name || '客服',
          remark: form.remark,
        }),
      '提交中…',
    )
    if (err) {
      ElMessage.warning(err)
      return
    }
    visible.value = false
    ElMessage.success(form.type === 'in' ? '入库成功' : '出库成功')
  })()
}

function goOrder(orderNo: string) {
  const o = store.orders.find((x) => x.orderNo === orderNo)
  if (o && can('orders:view')) router.push(`/orders/${o.id}`)
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
