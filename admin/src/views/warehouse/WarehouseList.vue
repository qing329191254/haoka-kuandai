<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>号卡仓库</span>
        <el-button v-if="can('warehouse:edit')" type="primary" @click="openEdit()">新增库存品</el-button>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="location" clearable placeholder="仓位" style="width: 160px">
        <el-option v-for="l in locations" :key="l" :label="l" :value="l" />
      </el-select>
      <el-select v-model="alert" clearable placeholder="库存预警" style="width: 140px">
        <el-option label="偏低" value="low" />
        <el-option label="正常" value="ok" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="产品 / SKU / 规格" style="width: 240px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="productName" label="产品" min-width="180" />
      <el-table-column prop="sku" label="SKU" width="130" />
      <el-table-column prop="spec" label="规格" width="120" />
      <el-table-column prop="location" label="仓位" width="130" />
      <el-table-column prop="stock" label="当前库存" width="100" />
      <el-table-column prop="safetyStock" label="安全库存" width="100" />
      <el-table-column label="预警" width="90">
        <template #default="{ row }">
          <el-tag v-if="row.stock <= row.safetyStock" type="danger" size="small">偏低</el-tag>
          <el-tag v-else type="success" size="small">正常</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="updatedAt" label="更新时间" width="170" />
      <el-table-column v-if="can('warehouse:edit') || can('stock:in')" label="操作" width="160" fixed="right">
        <template #default="{ row }">
          <el-button v-if="can('warehouse:edit')" link type="primary" @click="openEdit(row)">编辑档案</el-button>
          <el-button v-if="can('stock:in') || can('stock:out')" link type="success" @click="goStock">出入库</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑仓库档案' : '新增库存品'" width="480px">
      <el-form :model="form" label-width="88px">
        <el-form-item label="号卡套餐">
          <el-select v-model="form.productId" placeholder="选择号卡套餐" style="width: 100%" @change="onProduct">
            <el-option v-for="p in haokaProducts" :key="p.id" :label="`${p.name}（${p.city}）`" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="品名">
          <el-input v-model="form.productName" disabled />
        </el-form-item>
        <el-form-item label="SKU"><el-input v-model="form.sku" /></el-form-item>
        <el-form-item label="规格"><el-input v-model="form.spec" placeholder="号卡实体卡" /></el-form-item>
        <el-form-item label="仓位"><el-input v-model="form.location" /></el-form-item>
        <el-form-item label="安全库存">
          <el-input-number v-model="form.safetyStock" :min="0" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false">取消</el-button>
        <el-button type="primary" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </el-card>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, uniq, usePager } from '@/composables/usePager'
import type { WarehouseItem } from '@/types/stock'

const store = useAdminStore()
const router = useRouter()
const { can } = usePermission()
const location = ref<string>()
const alert = ref<'low' | 'ok'>()
const keyword = ref('')
const locations = computed(() => uniq(store.warehouse.map((w) => w.location)))
const haokaProducts = computed(() => store.products.filter((p) => p.bizType === 'haoka'))
const { page, pageSize, filtered, paged } = usePager(() =>
  store.warehouse.filter((w) => {
    if (location.value && w.location !== location.value) return false
    if (alert.value === 'low' && w.stock > w.safetyStock) return false
    if (alert.value === 'ok' && w.stock <= w.safetyStock) return false
    const k = keyword.value.trim()
    return includesKw(w.productName, k) || includesKw(w.sku, k) || includesKw(w.spec, k)
  }),
)
watch([location, alert, keyword], () => {
  page.value = 1
})
const visible = ref(false)
const form = reactive<WarehouseItem>({
  id: '',
  productId: '',
  productName: '',
  sku: '',
  spec: '',
  stock: 0,
  safetyStock: 0,
  location: '杭州仓',
  updatedAt: '',
})

function openEdit(row?: WarehouseItem) {
  Object.assign(
    form,
    row || {
      id: '',
      productId: haokaProducts.value[0]?.id || '',
      productName: haokaProducts.value[0]?.name || '',
      sku: '',
      spec: '号卡实体卡',
      stock: 0,
      safetyStock: 10,
      location: '杭州仓',
      updatedAt: '',
    },
  )
  visible.value = true
}

function onProduct(id: string) {
  form.productName = haokaProducts.value.find((p) => p.id === id)?.name || ''
  if (!form.spec) form.spec = '号卡实体卡'
}

async function save() {
  if (!form.productId || !form.sku.trim()) {
    ElMessage.warning('请选择号卡套餐并填写 SKU')
    return
  }
  const isNew = !form.id
  try {
    await store.upsertWarehouse({ ...form, id: form.id || `w${Date.now()}` })
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success(isNew ? '已建档' : '已保存')
}

function goStock() {
  router.push('/stock')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
