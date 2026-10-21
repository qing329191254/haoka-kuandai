<template>
  <el-row :gutter="16">
    <el-col :span="16">
      <el-card>
        <template #header>
          <div class="hd">
            <span>客服 FAQ</span>
            <el-button v-if="can('service:edit')" type="primary" @click="openEdit()">新增问题</el-button>
          </div>
        </template>
        <div class="toolbar">
          <el-select v-model="category" clearable placeholder="分类" style="width: 120px">
            <el-option v-for="c in categories" :key="c" :label="c" :value="c" />
          </el-select>
          <el-select v-model="showState" clearable placeholder="展示" style="width: 120px">
            <el-option label="启用" value="on" />
            <el-option label="隐藏" value="off" />
          </el-select>
          <el-input v-model="keyword" clearable placeholder="问题 / 答复" style="width: 200px" />
        </div>
        <el-table :data="paged" stripe>
          <el-table-column prop="sort" label="排序" width="70" />
          <el-table-column prop="category" label="分类" width="90" />
          <el-table-column prop="question" label="问题" min-width="180" />
          <el-table-column prop="answer" label="答复" min-width="240" show-overflow-tooltip />
          <el-table-column label="展示" width="80">
            <template #default="{ row }">
              <el-tag :type="row.enabled ? 'success' : 'info'" size="small">{{ row.enabled ? '启用' : '隐藏' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column v-if="can('service:edit')" label="操作" width="120">
            <template #default="{ row }">
              <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
              <el-button link type="danger" @click="onDelete(row)">删除</el-button>
            </template>
          </el-table-column>
        </el-table>
        <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />
      </el-card>
    </el-col>
    <el-col :span="8">
      <el-card>
        <template #header>
          <span>热线与快捷回复</span>
        </template>
        <el-form label-width="88px">
          <el-form-item label="客服热线">
            <el-input v-model="cfg.hotline" />
          </el-form-item>
          <el-form-item label="服务时间">
            <el-input v-model="cfg.workTime" />
          </el-form-item>
          <el-form-item label="快捷回复">
            <div class="qr-list">
              <div v-for="(item, i) in cfg.quickReplies" :key="i" class="qr-item">
                <div class="qr-hd">
                  <span>第 {{ i + 1 }} 条</span>
                  <el-button
                    v-if="can('service:edit')"
                    link
                    type="danger"
                    :disabled="cfg.quickReplies.length <= 1"
                    @click="removeReply(i)"
                  >
                    删除
                  </el-button>
                </div>
                <el-input v-model="item.prompt" placeholder="用户点一下发出去的问题" />
                <el-input
                  v-model="item.reply"
                  type="textarea"
                  resize="none"
                  :rows="3"
                  placeholder="用户点选后作为聊天消息发送的标签文案；下方可写补充说明"
                  style="margin-top: 8px"
                />
              </div>
              <el-button v-if="can('service:edit')" plain @click="addReply">添加一条</el-button>
            </div>
          </el-form-item>
          <el-button v-if="can('service:edit')" type="primary" @click="saveCfg">保存配置</el-button>
        </el-form>
      </el-card>
    </el-col>
  </el-row>

  <el-card style="margin-top: 16px">
    <template #header>
      <span>App 版本更新（无需对接应用商店 SDK）</span>
    </template>
    <el-alert
      type="info"
      :closable="false"
      show-icon
      title="Android 可填 apk 下载地址；iOS 可先填 App Store / TestFlight 链接，未上架可留空。"
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

  <el-dialog v-model="visible" :title="form.id ? '编辑 FAQ' : '新增 FAQ'" width="520px">
    <el-form :model="form" label-width="72px">
      <el-form-item label="分类">
        <el-select v-model="form.category" style="width: 100%">
          <el-option v-for="c in categories" :key="c" :label="c" :value="c" />
        </el-select>
      </el-form-item>
      <el-form-item label="排序">
        <el-input-number v-model="form.sort" :min="1" />
      </el-form-item>
      <el-form-item label="问题">
        <el-input v-model="form.question" />
      </el-form-item>
      <el-form-item label="答复">
        <el-input v-model="form.answer" type="textarea" resize="none" :rows="4" />
      </el-form-item>
      <el-form-item label="展示">
        <el-switch v-model="form.enabled" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button type="primary" @click="saveFaq">保存</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import type { AppVersionConfig, FaqItem } from '@/types/order'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()
const categories = ['入驻', '号卡', '宽带', '订单', '账号'] as const
const category = ref<(typeof categories)[number]>()
const showState = ref<'on' | 'off'>()
const keyword = ref('')
const { page, pageSize, filtered, paged } = usePager(() =>
  store.faqs.filter((f) => {
    if (category.value && f.category !== category.value) return false
    if (showState.value === 'on' && !f.enabled) return false
    if (showState.value === 'off' && f.enabled) return false
    const k = keyword.value.trim()
    return includesKw(f.question, k) || includesKw(f.answer, k)
  }),
)
watch([category, showState, keyword], () => {
  page.value = 1
})
const cfg = reactive({
  hotline: '',
  workTime: '',
  quickReplies: [] as { prompt: string; reply: string }[],
})
watch(
  () => store.serviceConfig,
  (value) => {
    cfg.hotline = value.hotline
    cfg.workTime = value.workTime
    cfg.quickReplies = value.quickReplies.map((q) => ({ ...q }))
  },
  { immediate: true },
)
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
const visible = ref(false)
const form = reactive<FaqItem>({
  id: '',
  category: '号卡',
  question: '',
  answer: '',
  enabled: true,
  sort: store.faqs.length + 1,
})

function openEdit(row?: FaqItem) {
  Object.assign(
    form,
    row
      ? { ...row }
      : { id: '', category: '号卡', question: '', answer: '', enabled: true, sort: store.faqs.length + 1 },
  )
  visible.value = true
}

async function saveFaq() {
  if (!form.question.trim() || !form.answer.trim()) {
    ElMessage.warning('请填写问题与答复')
    return
  }
  try {
    await withLoading(() => store.upsertFaq({ ...form, id: form.id || `f${Date.now()}` }), '保存中…')
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}

async function onDelete(row: FaqItem) {
  try {
    await ElMessageBox.confirm(`确定删除「${row.question}」？`, '删除 FAQ', { type: 'warning' })
  } catch {
    return
  }
  try {
    await withLoading(() => store.removeFaq(row.id), '删除中…')
    ElMessage.success('已删除')
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '删除失败')
  }
}

function addReply() {
  cfg.quickReplies.push({ prompt: '', reply: '' })
}

function removeReply(i: number) {
  cfg.quickReplies.splice(i, 1)
}

async function saveCfg() {
  const quickReplies = cfg.quickReplies.filter((q) => q.prompt.trim() && q.reply.trim())
  if (!quickReplies.length) {
    ElMessage.warning('请至少保留一条完整的快捷回复（问题 + 回答）')
    return
  }
  try {
    await withLoading(
      () =>
        store.saveServiceConfig({
          hotline: cfg.hotline,
          workTime: cfg.workTime,
          quickReplies,
        }),
      '保存中…',
    )
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  ElMessage.success('客服配置已保存')
}

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
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.hint {
  margin-left: 12px;
  color: #909399;
  font-size: 12px;
}
.qr-list {
  width: 100%;
}
.qr-item {
  margin-bottom: 12px;
  padding: 12px;
  border: 1px solid #e8eef6;
  border-radius: 12px;
  background: #f7faff;
}
.qr-hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  font-size: 12px;
  color: #7b8898;
}
</style>
