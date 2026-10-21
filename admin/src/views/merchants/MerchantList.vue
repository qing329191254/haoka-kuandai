<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>本地商家</span>
        <div class="hd-right">
          <el-text type="info" size="small">新商家优先由小程序入驻申请审核写入</el-text>
          <el-button v-if="can('merchants:edit')" type="primary" @click="openEdit()">新增商家</el-button>
        </div>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="状态" style="width: 120px">
        <el-option label="启用" value="active" />
        <el-option label="停用" value="disabled" />
      </el-select>
      <el-select v-model="province" clearable placeholder="省" style="width: 140px" @change="onFilterProvince">
        <el-option v-for="p in provinces" :key="p" :label="p" :value="p" />
      </el-select>
      <el-select v-model="city" clearable placeholder="市" style="width: 140px" @change="onFilterCity">
        <el-option v-for="c in cities" :key="c" :label="c" :value="c" />
      </el-select>
      <el-select v-model="district" clearable placeholder="区" style="width: 140px">
        <el-option v-for="d in districts" :key="d" :label="d" :value="d" />
      </el-select>
      <el-select v-model="bizType" clearable placeholder="可接业务" style="width: 180px">
        <el-option v-for="(label, key) in BIZ_TYPE_LABEL" :key="key" :label="label" :value="key" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="商家名称 / 联系人 / 电话" style="width: 240px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="商家名称" min-width="140" />
      <el-table-column prop="mpDisplayName" label="门店展示名" width="140" />
      <el-table-column prop="contact" label="联系人" width="90" />
      <el-table-column prop="phone" label="电话" width="140" />
      <el-table-column label="服务地区" min-width="180">
        <template #default="{ row }">{{ regionLabel(row) }}</template>
      </el-table-column>
      <el-table-column label="门店地址" min-width="160">
        <template #default="{ row }">{{ row.address || '-' }}</template>
      </el-table-column>
      <el-table-column label="可接业务" min-width="220">
        <template #default="{ row }">
          <el-tag v-for="t in row.bizTypes" :key="t" size="small" style="margin-right: 4px">
            {{ labelBiz(t) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '启用' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('merchants:edit')" label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="store.toggleById(store.merchants, row.id)">
            {{ row.status === 'active' ? '停用' : '启用' }}
          </el-button>
          <el-button link type="danger" @click="onRemove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑商家' : '新增商家'" width="580px">
      <el-form :model="form" label-width="110px">
        <el-form-item label="商家名称">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="门店展示名">
          <el-input v-model="form.mpDisplayName" />
        </el-form-item>
        <el-form-item label="联系人">
          <el-input v-model="form.contact" />
        </el-form-item>
        <el-form-item label="电话">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item label="服务地区" required>
          <RegionCascader
            :province="form.province"
            :city="form.city"
            :district="form.district"
            @change="onRegion"
          />
        </el-form-item>
        <el-form-item label="门店地址">
          <el-input v-model="form.address" placeholder="街道门牌，选填" />
        </el-form-item>
        <el-form-item label="可接业务">
          <el-checkbox-group v-model="form.bizTypes">
            <el-checkbox v-for="(label, key) in BIZ_TYPE_LABEL" :key="key" :label="key" :value="key">{{ label }}</el-checkbox>
          </el-checkbox-group>
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
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import RegionCascader from '@/components/RegionCascader.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, uniq, usePager } from '@/composables/usePager'
import {
  BIZ_TYPE_LABEL,
  labelBiz,
  regionLabel,
  type BizType,
  type EnableStatus,
  type Merchant,
} from '@/types/order'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<EnableStatus>()
const province = ref<string>()
const city = ref<string>()
const district = ref<string>()
const bizType = ref<BizType>()
const keyword = ref('')

const provinces = computed(() => uniq(store.merchants.map((m) => m.province)))
const cities = computed(() =>
  uniq(store.merchants.filter((m) => !province.value || m.province === province.value).map((m) => m.city)),
)
const districts = computed(() =>
  uniq(
    store.merchants
      .filter((m) => (!province.value || m.province === province.value) && (!city.value || m.city === city.value))
      .map((m) => m.district),
  ),
)

const { page, pageSize, filtered, paged } = usePager(() =>
  store.merchants.filter((m) => {
    if (status.value && m.status !== status.value) return false
    if (province.value && m.province !== province.value) return false
    if (city.value && m.city !== city.value) return false
    if (district.value && m.district !== district.value) return false
    if (bizType.value && !m.bizTypes.includes(bizType.value)) return false
    const k = keyword.value.trim()
    return (
      includesKw(m.name, k) ||
      includesKw(m.contact, k) ||
      includesKw(m.phone, k) ||
      includesKw(m.address, k) ||
      includesKw(regionLabel(m), k)
    )
  }),
)
watch([status, province, city, district, bizType, keyword], () => {
  page.value = 1
})

const visible = ref(false)
const form = reactive<Merchant>({
  id: '',
  name: '',
  phone: '',
  province: '',
  city: '',
  district: '',
  address: '',
  status: 'active',
  bizTypes: ['broadband_naked', 'broadband_new_card', 'broadband_no_card'],
  contact: '',
  mpDisplayName: '',
})

function onFilterProvince() {
  city.value = undefined
  district.value = undefined
}
function onFilterCity() {
  district.value = undefined
}

function onRegion(payload: { province: string; city: string; district: string }) {
  form.province = payload.province
  form.city = payload.city
  form.district = payload.district
}

function openEdit(row?: Merchant) {
  Object.assign(
    form,
    row
      ? { ...row, bizTypes: [...row.bizTypes] }
      : {
          id: '',
          name: '',
          phone: '',
          province: '浙江省',
          city: '杭州市',
          district: '西湖区',
          address: '',
          status: 'active',
          bizTypes: ['broadband_naked', 'broadband_new_card', 'broadband_no_card'] as BizType[],
          contact: '',
          mpDisplayName: '',
        },
  )
  visible.value = true
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写商家名称')
    return
  }
  if (!form.province || !form.city || !form.district) {
    ElMessage.warning('请选择完整的省 / 市 / 区')
    return
  }
  try {
    await withLoading(
      () =>
        store.upsertMerchant({
          ...form,
          id: form.id || `m${Date.now()}`,
          mpDisplayName: form.mpDisplayName || form.name,
          bizTypes: [...form.bizTypes],
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

async function onRemove(row: Merchant) {
  const techCount = store.technicians.filter((t) => t.merchantId === row.id).length
  try {
    await ElMessageBox.confirm(
      techCount > 0
        ? `确定删除「${row.name}」？其名下 ${techCount} 名上门师傅将一并删除。`
        : `确定删除本地商家「${row.name}」？`,
      '删除确认',
      { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  try {
    await withLoading(() => store.removeMerchant(row.id), '删除中…')
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '删除失败')
    return
  }
  ElMessage.success('已删除')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}
.hd-right {
  display: flex;
  align-items: center;
  gap: 12px;
}
</style>
