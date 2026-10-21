<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>商品套餐</span>
        <el-button v-if="can('products:edit')" type="primary" @click="openEdit()">新增套餐</el-button>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="bizType" clearable placeholder="业务类型" style="width: 170px">
        <el-option v-for="(label, key) in PRODUCT_TYPE_LABEL" :key="key" :label="label" :value="key" />
      </el-select>
      <el-select v-model="stockTypeId" clearable placeholder="存量业务类型" style="width: 160px">
        <el-option v-for="t in store.stockBizTypes" :key="t.id" :label="t.name" :value="t.id" />
      </el-select>
      <el-select v-model="city" clearable placeholder="地级市" style="width: 140px">
        <el-option v-for="c in cities" :key="c" :label="c" :value="c" />
      </el-select>
      <el-select v-model="carrier" clearable placeholder="运营商 / WIFI 公司" style="width: 170px">
        <el-option v-for="c in carriers" :key="c" :label="c" :value="c" />
      </el-select>
      <el-select v-model="status" clearable placeholder="上架状态" style="width: 130px">
        <el-option label="上架" value="active" />
        <el-option label="下架" value="disabled" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="套餐名称 / 说明" style="width: 220px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="套餐名称" min-width="170" />
      <el-table-column label="业务" width="130">
        <template #default="{ row }">{{ productTypeText(row) }}</template>
      </el-table-column>
      <el-table-column label="地级市" width="150">
        <template #default="{ row }">{{ productCityLabel(row) }}</template>
      </el-table-column>
      <el-table-column prop="carrier" label="运营商 / WIFI 公司" min-width="140" />
      <el-table-column label="WIFI 规格" width="120">
        <template #default="{ row }">
          <span v-if="row.bizType === 'wifi'">{{ row.wifiDeviceType || '-' }} · {{ row.wifiBizMode || '-' }}</span>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column prop="priceLabel" label="资费" width="110" />
      <el-table-column label="佣金" width="90">
        <template #default="{ row }">¥{{ row.commission }}</template>
      </el-table-column>
      <el-table-column prop="description" label="说明" min-width="180" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '上架' : '下架' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('products:edit')" label="操作" width="140" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="store.toggleById(store.products, row.id)">
            {{ row.status === 'active' ? '下架' : '上架' }}
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑套餐' : '新增套餐'" width="560px">
      <el-form :model="form" label-width="120px">
        <el-form-item label="业务类型">
          <el-select v-model="form.bizType" style="width: 100%" @change="onBizChange">
            <el-option v-for="(label, key) in PRODUCT_TYPE_LABEL" :key="key" :label="label" :value="key" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="form.bizType === 'stock'" label="存量业务类型">
          <el-select v-model="form.stockTypeId" style="width: 100%" placeholder="请选择已创建的业务类型">
            <el-option v-for="t in activeStockTypes" :key="t.id" :label="t.name" :value="t.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="套餐名称">
          <el-input v-model="form.name" placeholder="如：电信畅享卡 59元" />
        </el-form-item>
        <el-form-item label="地级市" required>
          <RegionCascader
            city-only
            :province="form.province"
            :city="form.city"
            placeholder="请选择省 / 地级市"
            @change="onCity"
          />
        </el-form-item>
        <el-form-item :label="carrierLabel">
          <el-input v-model="form.carrier" placeholder="电信 / 移动 / 联通，或填写 WIFI 公司名称" />
        </el-form-item>
        <el-form-item v-if="form.bizType === 'wifi'" label="设备类型">
          <el-radio-group v-model="form.wifiDeviceType">
            <el-radio value="4G">4G</el-radio>
            <el-radio value="5G">5G</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="form.bizType === 'wifi'" label="业务模式">
          <el-radio-group v-model="form.wifiBizMode">
            <el-radio value="买断">买断</el-radio>
            <el-radio value="租赁">租赁</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="资费">
          <el-input v-model="form.priceLabel" placeholder="如：59元/月" />
        </el-form-item>
        <el-form-item label="佣金（元）">
          <el-input-number v-model="form.commission" :min="0" :precision="0" style="width: 100%" />
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="form.description" type="textarea" resize="none" :rows="2" />
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
import { ElMessage } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import RegionCascader from '@/components/RegionCascader.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, uniq, usePager } from '@/composables/usePager'
import {
  productCityLabel,
  type EnableStatus,
  type Product,
  type ProductBizType,
} from '@/types/order'
import { withLoading } from '@/utils/loading'

const PRODUCT_TYPE_LABEL: Record<ProductBizType, string> = {
  haoka: '号卡',
  wifi: 'WIFI 设备',
  cpe: 'CPE',
  stock: '存量业务',
  broadband_naked: '裸宽',
  broadband_new_card: '融合宽带（新开卡）',
  broadband_no_card: '融合宽带（线上办理）',
}

const store = useAdminStore()
const { can } = usePermission()
const bizType = ref<ProductBizType>()
const stockTypeId = ref<string>()
const city = ref<string>()
const carrier = ref<string>()
const status = ref<EnableStatus>()
const keyword = ref('')
const carriers = computed(() => uniq(store.products.map((p) => p.carrier)))
const cities = computed(() => uniq(store.products.map((p) => p.city).filter(Boolean)))
const activeStockTypes = computed(() => store.stockBizTypes.filter((t) => t.status === 'active'))

const { page, pageSize, filtered, paged } = usePager(() =>
  store.products.filter((p) => {
    if (bizType.value && p.bizType !== bizType.value) return false
    if (stockTypeId.value && p.stockTypeId !== stockTypeId.value) return false
    if (city.value && p.city !== city.value) return false
    if (carrier.value && p.carrier !== carrier.value) return false
    if (status.value && p.status !== status.value) return false
    const k = keyword.value.trim()
    return includesKw(p.name, k) || includesKw(p.description, k)
  }),
)
watch([bizType, stockTypeId, city, carrier, status, keyword], () => {
  page.value = 1
})

const visible = ref(false)
const form = reactive<Product>(emptyForm())

function emptyForm(): Product {
  return {
    id: '',
    name: '',
    bizType: 'haoka',
    stockTypeId: undefined,
    carrier: '电信',
    priceLabel: '',
    description: '',
    status: 'active',
    province: '浙江省',
    city: '杭州市',
    commission: 0,
    wifiDeviceType: undefined,
    wifiBizMode: undefined,
  }
}

function productTypeText(row: Product) {
  if (row.bizType === 'stock') {
    const t = store.stockBizTypes.find((x) => x.id === row.stockTypeId)
    return t ? `存量 · ${t.name}` : '存量业务'
  }
  return PRODUCT_TYPE_LABEL[row.bizType]
}

const carrierLabel = computed(() =>
  form.bizType === 'wifi' || form.bizType === 'cpe' ? '运营商 / WIFI 公司' : '运营商',
)

function onBizChange() {
  if (form.bizType !== 'stock') form.stockTypeId = undefined
  if (form.bizType !== 'wifi') {
    form.wifiDeviceType = undefined
    form.wifiBizMode = undefined
  } else {
    form.wifiDeviceType = form.wifiDeviceType || '4G'
    form.wifiBizMode = form.wifiBizMode || '租赁'
  }
}

function onCity(payload: { province: string; city: string }) {
  form.province = payload.province
  form.city = payload.city
}

function openEdit(row?: Product) {
  Object.assign(form, row ? { ...row } : emptyForm())
  visible.value = true
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写套餐名称')
    return
  }
  if (!form.province || !form.city) {
    ElMessage.warning('请绑定地上架的地级市')
    return
  }
  if (form.bizType === 'stock' && !form.stockTypeId) {
    ElMessage.warning('请选择存量业务类型')
    return
  }
  if (form.bizType === 'wifi' && (!form.wifiDeviceType || !form.wifiBizMode)) {
    ElMessage.warning('WIFI 套餐请选择 4G/5G 与买断/租赁')
    return
  }
  if (form.commission < 0) {
    ElMessage.warning('请填写佣金')
    return
  }
  const dup = store.products.some(
    (p) =>
      p.id !== form.id &&
      p.name.trim() === form.name.trim() &&
      p.city === form.city &&
      p.bizType === form.bizType &&
      (p.stockTypeId || '') === (form.stockTypeId || ''),
  )
  if (dup) {
    ElMessage.warning('同一地级市已有同名套餐，请区分名称或改到其他城市')
    return
  }
  try {
    await withLoading(
      () =>
        store.upsertProduct({
          ...form,
          id: form.id || `p${Date.now()}`,
          stockTypeId: form.bizType === 'stock' ? form.stockTypeId : undefined,
          wifiDeviceType: form.bizType === 'wifi' ? form.wifiDeviceType : undefined,
          wifiBizMode: form.bizType === 'wifi' ? form.wifiBizMode : undefined,
        }),
      '保存中…',
    )
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
