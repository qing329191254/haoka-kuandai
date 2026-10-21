<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>角色权限</span>
        <el-button v-if="can('roles:edit')" type="primary" @click="openEdit()">新建角色</el-button>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="kind" clearable placeholder="类型" style="width: 140px">
        <el-option label="系统预置" value="builtin" />
        <el-option label="自定义" value="custom" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="角色名 / 说明" style="width: 240px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="角色" width="140" />
      <el-table-column label="类型" width="110">
        <template #default="{ row }">
          <el-tag :type="row.builtin ? 'warning' : 'info'" size="small">{{ row.builtin ? '系统预置' : '自定义' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="权限" min-width="220">
        <template #default="{ row }">
          <span v-if="row.permissions.includes('*')">全部权限</span>
          <span v-else>{{ row.permissions.length }} 项</span>
        </template>
      </el-table-column>
      <el-table-column prop="remark" label="说明" min-width="220" />
      <el-table-column v-if="can('roles:edit')" label="操作" width="160" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" :disabled="row.code === 'admin'" @click="openEdit(row)">配置权限</el-button>
          <el-button link type="danger" :disabled="row.builtin" @click="remove(row.id)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? `配置角色：${form.name}` : '新建角色'" width="560px">
      <el-form :model="form" label-width="72px">
        <el-form-item label="角色名" required>
          <el-input v-model="form.name" :disabled="form.builtin" placeholder="如：仓管、区域运营" />
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="form.remark" placeholder="一句话说明职责（选填）" />
        </el-form-item>
        <el-form-item label="权限" required>
          <el-tree
            ref="treeRef"
            :data="PERMISSION_TREE"
            node-key="id"
            show-checkbox
            default-expand-all
            :props="{ label: 'label', children: 'children' }"
            style="width: 100%; max-height: 360px; overflow: auto"
          />
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
import { nextTick, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { ElTree } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { ALL_PERMISSIONS, PERMISSION_TREE, type Permission, type Role } from '@/types/auth'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import { withLoading } from '@/utils/loading'

const { auth, can } = usePermission()
const kind = ref<'builtin' | 'custom'>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  auth.roles.filter((r) => {
    if (kind.value === 'builtin' && !r.builtin) return false
    if (kind.value === 'custom' && r.builtin) return false
    const k = keyword.value.trim()
    return includesKw(r.name, k) || includesKw(r.remark, k)
  }),
)
watch([kind, keyword], () => {
  page.value = 1
})
const visible = ref(false)
const treeRef = ref<InstanceType<typeof ElTree>>()
const form = reactive<Role>({
  id: '',
  name: '',
  code: '',
  builtin: false,
  permissions: [],
  remark: '',
})

function openEdit(row?: Role) {
  Object.assign(
    form,
    row
      ? { ...row, permissions: [...row.permissions] }
      : { id: '', name: '', code: '', builtin: false, permissions: [] as Permission[], remark: '' },
  )
  visible.value = true
  nextTick(() => {
    const keys = form.permissions.includes('*') ? ALL_PERMISSIONS : form.permissions
    treeRef.value?.setCheckedKeys(keys)
  })
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写角色名')
    return
  }
  const checked = (treeRef.value?.getCheckedKeys(true) || []) as string[]
  const permissions = checked.filter((k) => k.includes(':')) as Permission[]
  if (!permissions.length) {
    ElMessage.warning('请至少勾选一项权限')
    return
  }
  const isNew = !form.id
  const code = form.code || `role_${Date.now()}`
  try {
    const err = await withLoading(
      () =>
        auth.upsertRole({
          ...form,
          id: form.id || `r${Date.now()}`,
          // 标识仅系统内部使用：编辑时保留原值，新建时自动生成
          code: isNew ? code : form.code,
          name: form.name.trim(),
          permissions,
        }),
      '保存中…',
    )
    if (err) {
      ElMessage.warning(err)
      return
    }
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('角色已保存，绑定该角色的账号立即生效')
}

async function remove(id: string) {
  try {
    await ElMessageBox.confirm('确认删除该自定义角色？', '删除角色', { type: 'warning' })
  } catch {
    return
  }
  const err = await auth.removeRole(id)
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
</style>
