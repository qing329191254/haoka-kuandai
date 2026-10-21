<template>
  <el-card>
    <template #header>协议与帮助</template>
    <el-tabs v-model="tab">
      <el-tab-pane v-for="doc in store.docs" :key="doc.id" :label="doc.title" :name="doc.id">
        <p class="meta">最近更新：{{ doc.updatedAt }}</p>
        <div v-for="(sec, i) in editing[doc.id] || []" :key="i" class="sec">
          <el-input v-model="sec.heading" placeholder="标题" style="margin-bottom: 8px" :disabled="!can('content:edit')" />
          <el-input v-model="sec.body" type="textarea" resize="none" :rows="3" placeholder="正文" :disabled="!can('content:edit')" />
        </div>
        <el-button v-if="can('content:edit')" type="primary" @click="save(doc.id)">保存此文档</el-button>
      </el-tab-pane>
    </el-tabs>
  </el-card>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import type { ContentDoc } from '@/types/order'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()
const tab = ref<ContentDoc['id']>('agreement')
const editing = reactive<Record<string, { heading: string; body: string }[]>>({})

watch(
  () => store.docs,
  (docs) => {
    for (const doc of docs) {
      if (!editing[doc.id]) editing[doc.id] = doc.sections.map((s) => ({ ...s }))
    }
    if (docs.length && !docs.some((d) => d.id === tab.value)) tab.value = docs[0].id
  },
  { immediate: true },
)

async function save(id: ContentDoc['id']) {
  const origin = store.docs.find((d) => d.id === id)
  if (!origin) return
  try {
    await withLoading(
      () => store.saveDoc({ ...origin, sections: (editing[id] || []).map((s) => ({ ...s })) }),
      '保存中…',
    )
    ElMessage.success(`${origin.title}已保存`)
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
  }
}
</script>

<style scoped>
.meta {
  color: #909399;
  font-size: 12px;
  margin: 0 0 12px;
}
.sec {
  margin-bottom: 16px;
}
</style>
