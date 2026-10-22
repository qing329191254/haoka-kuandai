<template>
  <el-card shadow="never">
    <template #header>
      <span>App 版本更新</span>
    </template>
    <el-alert
      type="info"
      :closable="false"
      show-icon
      title="真实生效：App 启动可强制更新，「我的 → 检查更新」会拉取本页配置。无需对接应用商店 SDK；Android 填 apk 下载地址，iOS 填 App Store / TestFlight 链接（未上架可留空）。"
      style="margin-bottom: 16px"
    />
    <el-form label-width="120px" style="max-width: 720px">
      <el-form-item label="启用检查更新">
        <el-switch v-model="ver.enabled" :disabled="!can('service:edit')" />
      </el-form-item>
      <el-form-item label="最新版本号">
        <el-input v-model="ver.latestVersion" placeholder="如 1.0.1" :disabled="!can('service:edit')" />
      </el-form-item>
      <el-form-item label="最低可用版本">
        <el-input
          v-model="ver.minSupportedVersion"
          placeholder="低于此版本将强制更新"
          :disabled="!can('service:edit')"
        />
      </el-form-item>
      <el-form-item label="强制更新">
        <el-switch v-model="ver.forceUpdate" :disabled="!can('service:edit')" />
        <span class="hint">开启后，只要本地版本低于最新版本就强制更新</span>
      </el-form-item>
      <el-form-item label="弹窗标题">
        <el-input v-model="ver.title" :disabled="!can('service:edit')" />
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
      <el-form-item label="Android 下载">
        <el-input v-model="ver.androidUrl" placeholder="https://.../app.apk" :disabled="!can('service:edit')" />
      </el-form-item>
      <el-form-item label="iOS 链接">
        <el-input
          v-model="ver.iosUrl"
          placeholder="App Store 或 TestFlight 链接"
          :disabled="!can('service:edit')"
        />
      </el-form-item>
      <el-form-item>
        <el-button v-if="can('service:edit')" type="primary" @click="saveVer">保存版本配置</el-button>
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
    Object.assign(ver, value)
  },
  { immediate: true },
)

async function saveVer() {
  if (!ver.latestVersion.trim()) {
    ElMessage.warning('请填写最新版本号')
    return
  }
  try {
    await withLoading(() => store.saveAppVersion({ ...ver }), '保存中…')
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  ElMessage.success('版本配置已保存')
}
</script>

<style scoped>
.hint {
  margin-left: 12px;
  color: #909399;
  font-size: 12px;
}
</style>
