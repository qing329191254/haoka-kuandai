<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>上门师傅</span>
        <div class="hd-right">
          <el-text type="info" size="small">日常由商家在小程序自行新增；此处供运营查看与协助</el-text>
          <el-button v-if="can('technicians:edit')" type="primary" @click="openEdit()">新增师傅</el-button>
        </div>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="状态" style="width: 120px">
        <el-option label="在岗" value="active" />
        <el-option label="停用" value="disabled" />
      </el-select>
      <el-select v-model="merchantId" clearable placeholder="所属商家" style="width: 160px">
        <el-option v-for="m in store.merchants" :key="m.id" :label="m.name" :value="m.id" />
      </el-select>
      <el-select v-model="skill" clearable placeholder="技能" style="width: 180px">
        <el-option label="号卡" value="haoka" />
        <el-option label="合约机" value="contract_phone" />
        <el-option label="融合宽带（新开卡）" value="broadband_new_card" />
        <el-option label="WIFI 设备" value="wifi" />
        <el-option label="CPE" value="cpe" />
        <el-option label="存量业务" value="stock" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="姓名 / 手机号 / 地区" style="width: 240px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="姓名" width="110" />
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column prop="merchantName" label="所属商家" width="140" />
      <el-table-column label="服务地区" min-width="200">
        <template #default="{ row }">{{ regionLabel(row) }}</template>
      </el-table-column>
      <el-table-column label="可接技能" min-width="200">
        <template #default="{ row }">
          <el-tag v-for="t in row.skills" :key="t" size="small" style="margin-right: 4px">
            {{ labelBiz(t) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '在岗' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('technicians:edit')" label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="store.toggleById(store.technicians, row.id)">
            {{ row.status === 'active' ? '停用' : '启用' }}
          </el-button>
          <el-button link type="danger" @click="onRemove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑师傅' : '新增师傅'" width="560px">
      <el-form :model="form" label-width="88px">
        <el-form-item label="姓名">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item label="所属商家">
          <el-select v-model="form.merchantId" style="width: 100%" @change="onMerchant">
            <el-option v-for="m in store.merchants" :key="m.id" :label="m.name" :value="m.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="服务地区" required>
          <RegionCascader
            :province="form.province"
            :city="form.city"
            :district="form.district"
            placeholder="请选择省 / 市 / 区"
            @change="onRegion"
          />
        </el-form-item>
        <el-form-item label="技能">
          <el-checkbox-group v-model="form.skills">
            <el-checkbox label="haoka" value="haoka">号卡</el-checkbox>
            <el-checkbox label="contract_phone" value="contract_phone">合约机</el-checkbox>
            <el-checkbox label="broadband_new_card" value="broadband_new_card">融合宽带（新开卡）</el-checkbox>
            <el-checkbox label="wifi" value="wifi">WIFI 设备</el-checkbox>
            <el-checkbox label="cpe" value="cpe">CPE</el-checkbox>
            <el-checkbox label="stock" value="stock">存量业务</el-checkbox>
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
import { reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import RegionCascader from '@/components/RegionCascader.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import { labelBiz, regionLabel, type EnableStatus, type Technician } from '@/types/order'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<EnableStatus>()
const merchantId = ref<string>()
const skill = ref<Technician['skills'][number]>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  store.technicians.filter((t) => {
    if (status.value && t.status !== status.value) return false
    if (merchantId.value && t.merchantId !== merchantId.value) return false
    if (skill.value && !t.skills.includes(skill.value)) return false
    const k = keyword.value.trim()
    return (
      includesKw(t.name, k) ||
      includesKw(t.phone, k) ||
      includesKw(regionLabel(t), k) ||
      includesKw(t.merchantName, k)
    )
  }),
)
watch([status, merchantId, skill, keyword], () => {
  page.value = 1
})
const visible = ref(false)
const form = reactive<Technician>({
  id: '',
  name: '',
  phone: '',
  province: '',
  city: '',
  district: '',
  status: 'active',
  merchantId: '',
  merchantName: '',
  skills: ['haoka'],
})

function openEdit(row?: Technician) {
  const m0 = store.merchants[0]
  Object.assign(
    form,
    row
      ? { ...row, skills: [...row.skills] }
      : {
          id: '',
          name: '',
          phone: '',
          province: m0?.province || '浙江省',
          city: m0?.city || '杭州市',
          district: m0?.district || '西湖区',
          status: 'active',
          merchantId: m0?.id || '',
          merchantName: m0?.name || '',
          skills: ['haoka'] as Technician['skills'],
        },
  )
  visible.value = true
}

function onMerchant(id: string) {
  const m = store.merchants.find((x) => x.id === id)
  form.merchantName = m?.name || ''
  if (m && !form.id) {
    form.province = m.province
    form.city = m.city
    form.district = m.district
  }
}

function onRegion(payload: { province: string; city: string; district: string }) {
  form.province = payload.province
  form.city = payload.city
  form.district = payload.district
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写姓名')
    return
  }
  if (!form.merchantId) {
    ElMessage.warning('请选择所属商家')
    return
  }
  if (!form.province || !form.city || !form.district) {
    ElMessage.warning('请选择完整的省 / 市 / 区')
    return
  }
  try {
    await withLoading(
      () =>
        store.upsertTechnician({
          ...form,
          id: form.id || `t${Date.now()}`,
          skills: [...form.skills],
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

async function onRemove(row: Technician) {
  try {
    await ElMessageBox.confirm(`确定删除上门师傅「${row.name}」？`, '删除确认', {
      type: 'warning',
      confirmButtonText: '删除',
      cancelButtonText: '取消',
    })
  } catch {
    return
  }
  try {
    await withLoading(() => store.removeTechnician(row.id), '删除中…')
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
