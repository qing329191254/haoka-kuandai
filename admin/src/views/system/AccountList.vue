<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>后台账号</span>
        <el-button v-if="can('accounts:edit')" type="primary" @click="openEdit()">新增账号</el-button>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="roleId" clearable placeholder="角色" style="width: 160px">
        <el-option v-for="r in auth.roles" :key="r.id" :label="r.name" :value="r.id" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="账号 / 姓名" style="width: 220px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="username" label="登录账号" min-width="160" />
      <el-table-column prop="name" label="姓名" min-width="140" />
      <el-table-column label="角色" min-width="120">
        <template #default="{ row }">{{ roleName(row.roleId) }}</template>
      </el-table-column>
      <el-table-column prop="createdAt" label="创建时间" min-width="180" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '正常' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('accounts:edit')" label="操作" width="140" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button
            v-if="row.username !== 'admin' && row.id !== auth.current?.id"
            link
            type="danger"
            @click="onRemove(row)"
          >
            删除
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑账号' : '新增账号'" width="480px">
      <el-form :model="form" label-width="88px">
        <el-form-item label="登录账号">
          <el-input v-model="form.username" :disabled="form.username === 'admin' && !!form.id" />
        </el-form-item>
        <el-form-item label="姓名"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" placeholder="默认 123456" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="form.roleId" style="width: 100%" :disabled="form.username === 'admin' && !!form.id">
            <el-option v-for="r in auth.roles" :key="r.id" :label="r.name" :value="r.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="form.status" style="width: 100%" :disabled="form.username === 'admin'">
            <el-option label="正常" value="active" />
            <el-option label="停用" value="disabled" />
          </el-select>
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
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import type { Staff } from '@/types/auth'

const { auth, can } = usePermission()
const roleId = ref<string>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  auth.staff.filter((s) => {
    if (roleId.value && s.roleId !== roleId.value) return false
    const k = keyword.value.trim()
    return includesKw(s.username, k) || includesKw(s.name, k)
  }),
)
watch([roleId, keyword], () => {
  page.value = 1
})
const visible = ref(false)
const form = reactive<Staff>({
  id: '',
  username: '',
  password: '123456',
  name: '',
  roleId: '',
  status: 'active',
  createdAt: '',
})

function roleName(id: string) {
  return auth.roles.find((r) => r.id === id)?.name || '-'
}

function openEdit(row?: Staff) {
  Object.assign(
    form,
    row
      ? { ...row }
      : {
          id: '',
          username: '',
          password: '123456',
          name: '',
          roleId: auth.roles.find((r) => r.code === 'service')?.id || auth.roles[0]?.id || '',
          status: 'active',
          createdAt: '',
        },
  )
  visible.value = true
}

async function save() {
  if (!form.username.trim() || !form.name.trim()) {
    ElMessage.warning('请填写账号和姓名')
    return
  }
  const err = await auth.upsertStaff({
    ...form,
    id: form.id || `s${Date.now()}`,
    password: form.password || (form.id ? '' : '123456'),
    status: form.username === 'admin' ? 'active' : form.status || 'active',
  })
  if (err) {
    ElMessage.warning(err)
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}

async function onRemove(row: Staff) {
  try {
    await ElMessageBox.confirm(
      `确定删除后台账号「${row.username}」（${row.name}）？删除后无法再用该账号登录。`,
      '删除确认',
      { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  const err = await auth.removeStaff(row.id)
  if (err) {
    ElMessage.warning(err)
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
