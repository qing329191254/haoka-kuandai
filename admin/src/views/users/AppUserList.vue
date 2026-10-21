<template>
  <el-card>
    <template #header>App 用户</template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="状态" style="width: 140px">
        <el-option label="正常" value="active" />
        <el-option label="停用" value="disabled" />
      </el-select>
      <el-select v-model="gender" clearable placeholder="性别" style="width: 120px">
        <el-option label="男" value="男" />
        <el-option label="女" value="女" />
        <el-option label="保密" value="保密" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="昵称 / 手机号 / 邮箱" style="width: 260px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="nickname" label="昵称" width="120" />
      <el-table-column prop="phone" label="手机号" width="140" />
      <el-table-column prop="email" label="邮箱" min-width="180">
        <template #default="{ row }">{{ row.email || '-' }}</template>
      </el-table-column>
      <el-table-column prop="gender" label="性别" width="80" />
      <el-table-column prop="orderCount" label="订单数" width="90" />
      <el-table-column prop="createdAt" label="注册时间" width="180" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '正常' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('users:edit')" label="操作" width="100" fixed="right">
        <template #default="{ row }">
          <el-button link @click="store.toggleUser(row.id)">
            {{ row.status === 'active' ? '停用' : '启用' }}
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />
  </el-card>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import type { EnableStatus } from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<EnableStatus>()
const gender = ref<string>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  store.appUsers.filter((u) => {
    if (status.value && u.status !== status.value) return false
    if (gender.value && u.gender !== gender.value) return false
    const k = keyword.value.trim()
    return includesKw(u.nickname, k) || includesKw(u.phone, k) || includesKw(u.email, k)
  }),
)
watch([status, gender, keyword], () => {
  page.value = 1
})
</script>
