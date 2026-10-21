<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>客服留言 / 意见反馈</span>
        <el-tag v-if="pendingCount" type="warning" size="small">待处理 {{ pendingCount }}</el-tag>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="channel" clearable placeholder="来源" style="width: 140px">
        <el-option label="客服留言" value="service_message" />
        <el-option label="意见反馈" value="app_feedback" />
      </el-select>
      <el-select v-model="type" clearable placeholder="类型" style="width: 140px">
        <el-option v-for="t in types" :key="t" :label="t" :value="t" />
      </el-select>
      <el-select v-model="status" clearable placeholder="处理状态" style="width: 140px">
        <el-option label="待处理" value="pending" />
        <el-option label="已处理" value="handled" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="用户 / 联系方式 / 内容" style="width: 260px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column label="来源" width="100">
        <template #default="{ row }">
          <el-tag :type="row.channel === 'service_message' ? 'primary' : 'info'" size="small">
            {{ row.channel === 'service_message' ? '客服留言' : '意见反馈' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="type" label="类型" width="110" />
      <el-table-column prop="userName" label="用户" width="90" />
      <el-table-column prop="contact" label="联系方式" width="130" />
      <el-table-column prop="content" label="内容" min-width="220" show-overflow-tooltip />
      <el-table-column prop="createdAt" label="提交时间" width="170" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="row.status === 'handled' ? 'success' : 'warning'" size="small">
            {{ row.status === 'handled' ? '已处理' : '待处理' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="120" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openDetail(row)">
            {{ can('feedback:edit') && row.status === 'pending' ? '处理' : '查看' }}
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />
  </el-card>

  <el-drawer v-model="visible" :title="detailTitle" size="460px">
    <template v-if="current">
      <el-descriptions :column="1" border>
        <el-descriptions-item label="来源">
          {{ current.channel === 'service_message' ? '客服留言' : '意见反馈' }}
        </el-descriptions-item>
        <el-descriptions-item label="类型">{{ current.type }}</el-descriptions-item>
        <el-descriptions-item label="用户">{{ current.userName || '—' }}</el-descriptions-item>
        <el-descriptions-item label="联系方式">{{ current.contact || '—' }}</el-descriptions-item>
        <el-descriptions-item label="提交时间">{{ current.createdAt }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          {{ current.status === 'handled' ? '已处理' : '待处理' }}
        </el-descriptions-item>
        <el-descriptions-item v-if="current.handledBy" label="处理人">
          {{ current.handledBy }}
          <span v-if="current.handledAt" class="muted"> · {{ current.handledAt }}</span>
        </el-descriptions-item>
      </el-descriptions>

      <h4 class="block-title">用户内容</h4>
      <div class="content-box">{{ current.content }}</div>

      <template v-if="current.status === 'handled'">
        <h4 class="block-title">回复用户</h4>
        <div class="content-box reply">{{ current.reply || '（未填写回复）' }}</div>
        <h4 v-if="current.adminNote" class="block-title">内部备注</h4>
        <div v-if="current.adminNote" class="content-box note">{{ current.adminNote }}</div>
        <div v-if="can('feedback:edit')" class="actions">
          <el-button @click="reopen">重新打开</el-button>
        </div>
      </template>

      <template v-else-if="can('feedback:edit')">
        <h4 class="block-title">回复用户（将在 App 留言记录中展示）</h4>
        <el-input
          v-model="form.reply"
          type="textarea"
          :rows="4"
          resize="none"
          maxlength="500"
          show-word-limit
          placeholder="例如：已收到，订单进度为… / 请补充订单号…"
        />
        <h4 class="block-title">内部备注（选填，用户不可见）</h4>
        <el-input
          v-model="form.note"
          type="textarea"
          :rows="2"
          resize="none"
          maxlength="200"
          show-word-limit
          placeholder="给同事看的备注"
        />
        <div class="actions">
          <el-button @click="visible = false">取消</el-button>
          <el-button type="primary" :loading="saving" @click="submitHandle">回复并标记处理</el-button>
        </div>
      </template>
    </template>
  </el-drawer>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import type { FeedbackItem } from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const types: FeedbackItem['type'][] = ['功能建议', '体验问题', '订单相关', '入驻咨询', '号卡/宽带', '其他']
const type = ref<FeedbackItem['type']>()
const status = ref<FeedbackItem['status']>()
const channel = ref<FeedbackItem['channel']>()
const keyword = ref('')
const visible = ref(false)
const saving = ref(false)
const current = ref<FeedbackItem | null>(null)
const form = reactive({ reply: '', note: '' })

const pendingCount = computed(
  () => store.feedbacks.filter((f) => f.status === 'pending').length,
)

const detailTitle = computed(() => {
  if (!current.value) return '留言详情'
  return current.value.status === 'pending' ? '处理留言' : '留言详情'
})

const { page, pageSize, filtered, paged } = usePager(() =>
  store.feedbacks.filter((f) => {
    if (channel.value && (f.channel || 'app_feedback') !== channel.value) return false
    if (type.value && f.type !== type.value) return false
    if (status.value && f.status !== status.value) return false
    const k = keyword.value.trim()
    return (
      includesKw(f.userName, k) ||
      includesKw(f.contact, k) ||
      includesKw(f.content, k) ||
      includesKw(f.reply || '', k)
    )
  }),
)

watch([type, status, channel, keyword], () => {
  page.value = 1
})

function openDetail(row: FeedbackItem) {
  current.value = row
  form.reply = row.reply || ''
  form.note = row.adminNote || ''
  visible.value = true
}

async function submitHandle() {
  if (!current.value) return
  if (!form.reply.trim()) {
    ElMessage.warning('请填写回复内容')
    return
  }
  saving.value = true
  try {
    await store.handleFeedback(current.value.id, {
      reply: form.reply.trim(),
      note: form.note.trim(),
    })
    ElMessage.success('已回复并标记处理')
    visible.value = false
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '处理失败')
  } finally {
    saving.value = false
  }
}

async function reopen() {
  if (!current.value) return
  try {
    await store.reopenFeedback(current.value.id)
    ElMessage.success('已重新打开')
    const next = store.feedbacks.find((f) => f.id === current.value?.id)
    if (next) openDetail(next)
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '操作失败')
  }
}
</script>

<style scoped>
.hd {
  display: flex;
  align-items: center;
  gap: 10px;
}
.muted {
  color: #909399;
  font-size: 12px;
}
.block-title {
  margin: 18px 0 8px;
  font-size: 14px;
  color: #303133;
}
.content-box {
  padding: 12px;
  border-radius: 8px;
  background: #f5f7fa;
  color: #303133;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}
.content-box.reply {
  background: #ecf5ff;
}
.content-box.note {
  background: #fdf6ec;
}
.actions {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>
