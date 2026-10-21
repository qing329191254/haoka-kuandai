<template>
  <el-result icon="warning" title="没有访问权限" sub-title="当前角色未开通该功能，请联系管理员在「角色权限」中配置。">
    <template #extra>
      <el-button type="primary" @click="goHome">返回可访问页面</el-button>
    </template>
  </el-result>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

function goHome() {
  router.replace(auth.firstAllowedPath())
}
</script>
