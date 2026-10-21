<template>
  <div class="cs-wrap">
    <el-card class="list-card" shadow="never">
      <template #header>
        <div class="hd">
          <span>在线客服</span>
          <el-tag v-if="unreadTotal" type="danger" size="small">待回复 {{ unreadTotal }}</el-tag>
          <el-button link type="primary" @click="reload">刷新</el-button>
        </div>
      </template>
      <div class="toolbar">
        <el-select v-model="status" clearable placeholder="状态" style="width: 120px">
          <el-option label="进行中" value="open" />
          <el-option label="已关闭" value="closed" />
        </el-select>
        <el-input v-model="keyword" clearable placeholder="用户 / 手机号 / 最近消息" style="width: 260px" />
      </div>
      <el-table
        :data="paged"
        stripe
        highlight-current-row
        :row-class-name="rowClass"
        @row-click="openChat"
      >
        <el-table-column label="用户" width="120">
          <template #default="{ row }">{{ row.userName || '用户' }}</template>
        </el-table-column>
        <el-table-column prop="userPhone" label="手机号" width="130" />
        <el-table-column prop="lastMessage" label="最近消息" min-width="200" show-overflow-tooltip />
        <el-table-column prop="lastMessageAt" label="时间" width="170" />
        <el-table-column label="未读" width="80">
          <template #default="{ row }">
            <el-badge v-if="row.agentUnread" :value="row.agentUnread" />
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 'open' ? 'success' : 'info'" size="small">
              {{ row.status === 'open' ? '进行中' : '已关闭' }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>
      <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />
    </el-card>

    <el-drawer
      v-model="visible"
      :title="drawerTitle"
      size="520px"
      destroy-on-close
      @closed="onDrawerClosed"
    >
      <div v-if="current" class="chat-pane">
        <div ref="scrollEl" class="msg-list">
          <div v-for="(m, i) in messages" :key="m.id" class="msg-block">
            <div v-if="showTime(m, messages[i - 1])" class="time">{{ m.createdAt }}</div>
            <div class="row" :class="m.senderType === 'user' ? 'user' : 'agent'">
              <div class="meta">
                <template v-if="m.senderType === 'user'">用户</template>
                <template v-else>
                  {{ m.displayName || '派客邦客服' }}
                  <span v-if="m.agentName" class="agent-real">（{{ m.agentName }}）</span>
                </template>
              </div>
              <div class="bubble" :class="m.senderType">
                <img v-if="m.msgType === 'image'" :src="m.content" class="img" alt="图片" />
                <span v-else>{{ m.content }}</span>
              </div>
            </div>
          </div>
        </div>
        <div v-if="can('feedback:edit')" class="composer">
          <el-input
            v-model="draft"
            type="textarea"
            :rows="3"
            resize="none"
            maxlength="2000"
            show-word-limit
            placeholder="输入回复内容，Enter 发送（Shift+Enter 换行）"
            @keydown="onKeydown"
          />
          <div class="actions">
            <el-button v-if="current.status === 'open'" @click="closeConv">结束会话</el-button>
            <el-button type="primary" :loading="sending" @click="send">发送</el-button>
          </div>
        </div>
        <div v-else class="readonly-tip">当前账号仅可查看，无回复权限</div>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { get, post } from '@/api/http'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import { withLoading } from '@/utils/loading'

export interface CsConversation {
  id: string
  userId: string
  userName: string
  userPhone: string
  status: 'open' | 'closed' | string
  lastMessage: string
  lastMessageAt: string
  userUnread: number
  agentUnread: number
  createdAt: string
  updatedAt: string
}

export interface CsMessage {
  id: string
  conversationId: string
  senderType: 'user' | 'agent' | 'system' | string
  agentId: string
  agentName: string
  displayName: string
  msgType: 'text' | 'image' | string
  content: string
  createdAt: string
}

const { can } = usePermission()
const conversations = ref<CsConversation[]>([])
const status = ref<string>()
const keyword = ref('')
const visible = ref(false)
const current = ref<CsConversation | null>(null)
const messages = ref<CsMessage[]>([])
const draft = ref('')
const sending = ref(false)
const scrollEl = ref<HTMLElement | null>(null)
let pollTimer: ReturnType<typeof setInterval> | null = null

const unreadTotal = computed(
  () => conversations.value.filter((c) => c.status === 'open' && c.agentUnread > 0).length,
)

const { page, pageSize, filtered, paged } = usePager(() =>
  conversations.value.filter((c) => {
    if (status.value && c.status !== status.value) return false
    const k = keyword.value.trim()
    return (
      includesKw(c.userName, k) || includesKw(c.userPhone, k) || includesKw(c.lastMessage, k)
    )
  }),
)

watch([status, keyword], () => {
  page.value = 1
})

const drawerTitle = computed(() => {
  if (!current.value) return '会话'
  const name = current.value.userName || '用户'
  return `${name} · ${current.value.userPhone || ''}`
})

function rowClass({ row }: { row: CsConversation }) {
  return row.agentUnread > 0 ? 'unread-row' : ''
}

async function reload() {
  try {
    const res = await get<{ items?: CsConversation[] }>('/api/admin/cs/conversations')
    conversations.value = res.items || []
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '加载失败')
  }
}

async function openChat(row: CsConversation) {
  current.value = row
  visible.value = true
  draft.value = ''
  try {
    await withLoading(async () => {
      const res = await get<{
        conversation: CsConversation
        messages: CsMessage[]
      }>(`/api/admin/cs/conversations/${row.id}`)
      current.value = res.conversation
      messages.value = res.messages || []
      const idx = conversations.value.findIndex((c) => c.id === row.id)
      if (idx >= 0) conversations.value[idx] = res.conversation
    }, '加载中…')
    await scrollBottom()
    startPoll()
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '打开会话失败')
  }
}

function startPoll() {
  stopPoll()
  pollTimer = setInterval(() => void pollMessages(), 3000)
}

function stopPoll() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

async function pollMessages() {
  if (!current.value || !visible.value) return
  const after = messages.value.length ? messages.value[messages.value.length - 1].id : ''
  try {
    const res = await get<{ items?: CsMessage[] }>(
      `/api/admin/cs/conversations/${current.value.id}/messages`,
      after ? { after } : undefined,
    )
    const items = res.items || []
    if (!items.length) return
    const known = new Set(messages.value.map((m) => m.id))
    const fresh = items.filter((m) => !known.has(m.id))
    if (!fresh.length) return
    messages.value.push(...fresh)
    await scrollBottom()
    await reload()
  } catch {
    /* ignore */
  }
}

async function scrollBottom() {
  await nextTick()
  const el = scrollEl.value
  if (el) el.scrollTop = el.scrollHeight
}

function showTime(cur: CsMessage, prev?: CsMessage) {
  if (!prev) return true
  return cur.createdAt.slice(0, 16) !== prev.createdAt.slice(0, 16)
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    void send()
  }
}

async function send() {
  if (!current.value || !can('feedback:edit')) return
  const text = draft.value.trim()
  if (!text || sending.value) return
  sending.value = true
  try {
    const res = await post<{ item: CsMessage }>(
      `/api/admin/cs/conversations/${current.value.id}/messages`,
      { content: text, msgType: 'text' },
    )
    draft.value = ''
    if (res.item && !messages.value.some((m) => m.id === res.item.id)) {
      messages.value.push(res.item)
    }
    await scrollBottom()
    await reload()
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '发送失败')
  } finally {
    sending.value = false
  }
}

async function closeConv() {
  if (!current.value) return
  try {
    await withLoading(
      () => post(`/api/admin/cs/conversations/${current.value!.id}/close`),
      '提交中…',
    )
    ElMessage.success('会话已结束')
    await reload()
    const next = conversations.value.find((c) => c.id === current.value?.id)
    if (next) current.value = next
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '操作失败')
  }
}

function onDrawerClosed() {
  stopPoll()
  current.value = null
  messages.value = []
  void reload()
}

onUnmounted(() => stopPoll())

void reload()
</script>

<style scoped>
.hd {
  display: flex;
  align-items: center;
  gap: 10px;
}
.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
}
.muted {
  color: #c0c4cc;
}
:deep(.unread-row) {
  font-weight: 600;
}
.chat-pane {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 120px);
}
.msg-list {
  flex: 1;
  overflow: auto;
  padding: 8px 4px 16px;
  background: #f5f7fa;
  border-radius: 8px;
}
.time {
  text-align: center;
  color: #909399;
  font-size: 12px;
  margin: 10px 0;
}
.row {
  display: flex;
  flex-direction: column;
  margin-bottom: 10px;
}
.row.user {
  align-items: flex-end;
}
.row.agent {
  align-items: flex-start;
}
.meta {
  font-size: 12px;
  color: #909399;
  margin-bottom: 4px;
}
.agent-real {
  color: #c0c4cc;
}
.bubble {
  max-width: 86%;
  padding: 10px 12px;
  border-radius: 12px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 14px;
}
.bubble.user {
  background: #95ec69;
  color: #1a2333;
  border-bottom-right-radius: 4px;
}
.bubble.agent,
.bubble.system {
  background: #fff;
  color: #1a2333;
  border-bottom-left-radius: 4px;
}
.img {
  max-width: 200px;
  border-radius: 8px;
  display: block;
}
.composer {
  margin-top: 12px;
}
.actions {
  margin-top: 10px;
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.readonly-tip {
  margin-top: 12px;
  color: #909399;
  font-size: 13px;
}
</style>
