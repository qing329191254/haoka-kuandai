<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>代理商</span>
        <el-button v-if="can('agents:edit')" type="primary" @click="openEdit()">新增代理商</el-button>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="合作状态" style="width: 140px">
        <el-option label="合作中" value="active" />
        <el-option label="已停用" value="disabled" />
      </el-select>
      <el-select v-model="province" clearable placeholder="省" style="width: 140px" @change="city = undefined">
        <el-option v-for="p in provinces" :key="p" :label="p" :value="p" />
      </el-select>
      <el-select v-model="city" clearable placeholder="市" style="width: 140px">
        <el-option v-for="c in cities" :key="c" :label="c" :value="c" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="名称 / 联系人 / 手机号" style="width: 260px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="公司 / 门店" min-width="140" />
      <el-table-column prop="contact" label="联系人" width="90" />
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column label="合作区域" min-width="180">
        <template #default="{ row }">{{ agentRegionLabel(row) }}</template>
      </el-table-column>
      <el-table-column prop="joinedAt" label="入驻时间" width="170" />
      <el-table-column prop="orderCount" label="订单数" width="90" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '合作中' : '已停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="remark" label="备注" min-width="120">
        <template #default="{ row }">{{ row.remark || '-' }}</template>
      </el-table-column>
      <el-table-column v-if="can('agents:edit')" label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="store.toggleById(store.agents, row.id)">
            {{ row.status === 'active' ? '停用' : '启用' }}
          </el-button>
          <el-button link type="danger" @click="onRemove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑代理商' : '新增代理商'" width="560px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="公司 / 门店"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="联系人"><el-input v-model="form.contact" /></el-form-item>
        <el-form-item label="手机号"><el-input v-model="form.phone" /></el-form-item>
        <el-form-item label="合作区域" required>
          <RegionCascader
            :province="form.province"
            :city="form.city"
            :district="form.district"
            @change="onRegion"
          />
        </el-form-item>
        <el-form-item label="详细地址"><el-input v-model="form.address" /></el-form-item>
        <el-form-item label="微信"><el-input v-model="form.wechat" /></el-form-item>
        <el-form-item label="备用电话"><el-input v-model="form.backupPhone" /></el-form-item>
        <el-form-item label="证件号码"><el-input v-model="form.idNo" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.remark" /></el-form-item>
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
import { agentRegionLabel, type Agent } from '@/types/stock'
import type { EnableStatus } from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<EnableStatus>()
const province = ref<string>()
const city = ref<string>()
const keyword = ref('')
const provinces = computed(() => uniq(store.agents.map((a) => a.province)))
const cities = computed(() =>
  uniq(store.agents.filter((a) => !province.value || a.province === province.value).map((a) => a.city)),
)
const { page, pageSize, filtered, paged } = usePager(() =>
  store.agents.filter((a) => {
    if (status.value && a.status !== status.value) return false
    if (province.value && a.province !== province.value) return false
    if (city.value && a.city !== city.value) return false
    const k = keyword.value.trim()
    return (
      includesKw(a.name, k) ||
      includesKw(a.contact, k) ||
      includesKw(a.phone, k) ||
      includesKw(agentRegionLabel(a), k)
    )
  }),
)
watch([status, province, city, keyword], () => {
  page.value = 1
})

const visible = ref(false)
const form = reactive<Agent>({
  id: '',
  name: '',
  phone: '',
  contact: '',
  province: '',
  city: '',
  district: '',
  address: '',
  wechat: '',
  backupPhone: '',
  idNo: '',
  joinedAt: '',
  orderCount: 0,
  status: 'active',
  remark: '',
})

function onRegion(payload: { province: string; city: string; district: string }) {
  form.province = payload.province
  form.city = payload.city
  form.district = payload.district
}

function openEdit(row?: Agent) {
  const now = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  const joined = `${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())} ${p(now.getHours())}:${p(now.getMinutes())}:00`
  Object.assign(
    form,
    row || {
      id: '',
      name: '',
      phone: '',
      contact: '',
      province: '浙江省',
      city: '杭州市',
      district: '西湖区',
      address: '',
      wechat: '',
      backupPhone: '',
      idNo: '',
      joinedAt: joined,
      orderCount: 0,
      status: 'active',
      remark: '',
    },
  )
  visible.value = true
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写公司 / 门店名称')
    return
  }
  if (!form.province || !form.city || !form.district) {
    ElMessage.warning('请选择完整合作区域')
    return
  }
  try {
    await store.upsertAgent({ ...form, id: form.id || `a${Date.now()}` })
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}

async function onRemove(row: Agent) {
  try {
    await ElMessageBox.confirm(`确定删除代理商「${row.name}」？`, '删除确认', {
      type: 'warning',
      confirmButtonText: '删除',
    })
  } catch {
    return
  }
  try {
    await store.removeAgent(row.id)
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
}
</style>
