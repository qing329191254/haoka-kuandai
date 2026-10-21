<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>押金规则</span>
        <el-button v-if="can('agents:edit')" type="primary" @click="openEdit()">新增规则</el-button>
      </div>
    </template>
    <p class="hint">
      匹配顺序：指定城市 + 规模 → 全省该规模 → 全国该规模。电子签合同仍用同一套模板，金额按入驻时锁定的规则写入申请单。
    </p>
    <el-table :data="paged" stripe>
      <el-table-column label="适用范围" min-width="180">
        <template #default="{ row }">{{ row.scope || scopeText(row) }}</template>
      </el-table-column>
      <el-table-column label="合作规模" width="110">
        <template #default="{ row }">{{ row.scaleLabel || scaleText(row.scale) }}</template>
      </el-table-column>
      <el-table-column label="押金（元）" width="120">
        <template #default="{ row }">¥{{ row.amount }}</template>
      </el-table-column>
      <el-table-column prop="remark" label="备注" min-width="160" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '启用' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('agents:edit')" label="操作" width="180" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="toggle(row)">{{ row.status === 'active' ? '停用' : '启用' }}</el-button>
          <el-button link type="danger" @click="onRemove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="store.depositRules.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑押金规则' : '新增押金规则'" width="520px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="适用范围">
          <el-radio-group v-model="scopeKind" @change="onScopeKind">
            <el-radio-button label="nation" value="nation">全国默认</el-radio-button>
            <el-radio-button label="province" value="province">全省</el-radio-button>
            <el-radio-button label="city" value="city">指定城市</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="scopeKind !== 'nation'" :label="scopeKind === 'city' ? '城市' : '省份'">
          <RegionCascader
            city-only
            :check-strictly="scopeKind === 'province'"
            :province="form.province"
            :city="form.city"
            :placeholder="scopeKind === 'city' ? '请选择省 / 市' : '请选择省份（点选省级即可）'"
            @change="onRegion"
          />
        </el-form-item>
        <el-form-item label="合作规模">
          <el-select v-model="form.scale" style="width: 100%">
            <el-option v-for="s in SCALE_OPTIONS" :key="s.id" :label="s.label" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="押金金额">
          <el-input-number v-model="form.amount" :min="1" :step="500" style="width: 100%" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.remark" placeholder="选填" />
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
import { reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import RegionCascader from '@/components/RegionCascader.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { usePager } from '@/composables/usePager'
import { SCALE_OPTIONS, type DepositRule } from '@/types/stock'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()
const { page, pageSize, paged } = usePager(() => store.depositRules)

const visible = ref(false)
const scopeKind = ref<'nation' | 'province' | 'city'>('nation')
const form = reactive<DepositRule>({
  id: '',
  province: '',
  city: '',
  scale: 'city',
  amount: 5000,
  remark: '',
  status: 'active',
})

function scaleText(code: string) {
  return SCALE_OPTIONS.find((s) => s.id === code)?.label || code
}

function scopeText(row: DepositRule) {
  if (row.province && row.city) return `${row.province} / ${row.city}`
  if (row.province) return `${row.province}（全省）`
  return '全国'
}

function kindOf(row: DepositRule): 'nation' | 'province' | 'city' {
  if (row.city) return 'city'
  if (row.province) return 'province'
  return 'nation'
}

function onScopeKind() {
  if (scopeKind.value === 'nation') {
    form.province = ''
    form.city = ''
  } else if (scopeKind.value === 'province') {
    form.city = ''
  }
}

function onRegion(v: { province: string; city: string }) {
  form.province = v.province
  form.city = scopeKind.value === 'city' ? v.city : ''
}

function openEdit(row?: DepositRule) {
  if (row) {
    Object.assign(form, { ...row })
    scopeKind.value = kindOf(row)
  } else {
    Object.assign(form, {
      id: '',
      province: '',
      city: '',
      scale: 'city',
      amount: 5000,
      remark: '',
      status: 'active' as const,
    })
    scopeKind.value = 'nation'
  }
  visible.value = true
}

async function save() {
  if (scopeKind.value === 'nation') {
    form.province = ''
    form.city = ''
  }
  if (scopeKind.value === 'province') {
    if (!form.province) {
      ElMessage.warning('请选择省份')
      return
    }
    form.city = ''
  }
  if (scopeKind.value === 'city' && (!form.province || !form.city)) {
    ElMessage.warning('请选择城市')
    return
  }
  if (!form.amount || form.amount <= 0) {
    ElMessage.warning('请填写押金金额')
    return
  }
  try {
    await withLoading(() => store.upsertDepositRule({ ...form, id: form.id || `dr${Date.now()}` }), '保存中…')
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}

async function toggle(row: DepositRule) {
  try {
    await withLoading(
      () =>
        store.upsertDepositRule({
          ...row,
          status: row.status === 'active' ? 'disabled' : 'active',
        }),
      '保存中…',
    )
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '操作失败')
  }
}

async function onRemove(row: DepositRule) {
  try {
    await ElMessageBox.confirm(`删除规则「${scopeText(row)} · ${scaleText(row.scale)}」？`, '删除确认', {
      type: 'warning',
    })
  } catch {
    return
  }
  const err = await withLoading(() => store.removeDepositRule(row.id), '删除中…')
  if (err) ElMessage.warning(err)
  else ElMessage.success('已删除')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.hint {
  margin: 0 0 12px;
  font-size: 13px;
  color: #7b8898;
  line-height: 1.5;
}
</style>
