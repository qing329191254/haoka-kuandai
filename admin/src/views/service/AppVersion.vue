<template>
  <el-card shadow="never">
    <template #header>
      <span>App 版本更新</span>
    </template>
    <el-form label-width="128px" style="max-width: 640px">
      <el-form-item label="启用检查更新">
        <el-switch v-model="ver.enabled" :disabled="!can('service:edit')" />
      </el-form-item>
      <el-form-item label="最新版本号">
        <el-input v-model="ver.latestVersion" placeholder="如 1.0.1" :disabled="!can('service:edit')" />
        <div class="hint-block">用户手动「检查更新」时与此比较；不强制拦截</div>
      </el-form-item>
      <el-form-item label="最低可用版本">
        <el-input
          v-model="ver.minSupportedVersion"
          placeholder="如 1.0.0"
          :disabled="!can('service:edit')"
        />
        <div class="hint-block">
          低于此版本：启动强制弹窗并跳转应用商店，不更新无法使用（仅严重问题调高）
        </div>
      </el-form-item>
      <el-form-item label="弹窗标题">
        <el-input v-model="ver.title" placeholder="如：版本过低" :disabled="!can('service:edit')" />
      </el-form-item>
      <el-form-item label="更新说明">
        <el-input
          v-model="ver.releaseNotes"
          type="textarea"
          :rows="3"
          resize="none"
          :disabled="!can('service:edit')"
        />
      </el-form-item>
      <el-form-item label="App Store">
        <el-input
          v-model="ver.iosUrl"
          placeholder="上架后填一次 App Store 详情页链接"
          :disabled="!can('service:edit')"
        />
        <div class="hint-block">Android 按 App 包名自动跳转商店，无需配置</div>
      </el-form-item>
      <el-form-item>
        <el-button v-if="can('service:edit')" type="primary" @click="saveVer">保存</el-button>
      </el-form-item>
    </el-form>
  </el-card>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import type { AppVersionConfig } from '@/types/order'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()

const ver = reactive<AppVersionConfig>({
  latestVersion: '1.0.0',
  minSupportedVersion: '1.0.0',
  forceUpdate: false,
  title: '发现新版本',
  releaseNotes: '',
  androidUrl: '',
  iosUrl: '',
  enabled: true,
})

watch(
  () => store.appVersion,
  (value) => {
    Object.assign(ver, {
      ...value,
      forceUpdate: false,
      androidUrl: '',
    })
  },
  { immediate: true },
)

async function saveVer() {
  if (!ver.latestVersion.trim()) {
    ElMessage.warning('请填写最新版本号')
    return
  }
  try {
    await withLoading(
      () =>
        store.saveAppVersion({
          ...ver,
          forceUpdate: false,
          androidUrl: '',
        }),
      '保存中…',
    )
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  ElMessage.success('已保存')
}
</script>

<style scoped>
.hint-block {
  margin-top: 6px;
  color: #909399;
  font-size: 12px;
  line-height: 1.5;
}
</style>
