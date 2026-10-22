import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { csEventsUrl, get } from '@/api/http'

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

function asConversation(raw: Partial<CsConversation> | null | undefined): CsConversation | null {
  if (!raw || !raw.id) return null
  return {
    id: String(raw.id),
    userId: String(raw.userId || ''),
    userName: String(raw.userName || ''),
    userPhone: String(raw.userPhone || ''),
    status: String(raw.status || 'open'),
    lastMessage: String(raw.lastMessage || ''),
    lastMessageAt: String(raw.lastMessageAt || ''),
    userUnread: Number(raw.userUnread || 0),
    agentUnread: Number(raw.agentUnread || 0),
    createdAt: String(raw.createdAt || ''),
    updatedAt: String(raw.updatedAt || ''),
  }
}

function asMessage(raw: Partial<CsMessage> | null | undefined): CsMessage | null {
  if (!raw || !raw.id) return null
  return {
    id: String(raw.id),
    conversationId: String(raw.conversationId || ''),
    senderType: String(raw.senderType || 'user'),
    agentId: String(raw.agentId || ''),
    agentName: String(raw.agentName || ''),
    displayName: String(raw.displayName || ''),
    msgType: String(raw.msgType || 'text'),
    content: String(raw.content || ''),
    createdAt: String(raw.createdAt || ''),
  }
}

/** 后台客服实时：SSE（HTTPS），不再依赖现网异常的 WSS 下行。 */
export const useCsChatStore = defineStore('csChat', () => {
  const conversations = ref<CsConversation[]>([])
  const liveMessages = ref<CsMessage[]>([])
  const watchedId = ref('')
  const wsStatus = ref<'off' | 'connecting' | 'live' | 'retry'>('off')

  let source: EventSource | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let pollTimer: ReturnType<typeof setInterval> | null = null
  let alive = false
  let gen = 0
  let backoffMs = 2000

  const unreadTotal = computed(
    () => conversations.value.filter((c) => c.status === 'open' && c.agentUnread > 0).length,
  )

  function upsertConversation(raw: Partial<CsConversation>) {
    const item = asConversation(raw)
    if (!item) return
    const idx = conversations.value.findIndex((c) => c.id === item.id)
    const next = conversations.value.slice()
    if (idx >= 0) next.splice(idx, 1, item)
    else next.unshift(item)
    next.sort((a, b) => (b.lastMessageAt || '').localeCompare(a.lastMessageAt || ''))
    conversations.value = next
  }

  function pushLiveMessage(raw: Partial<CsMessage>) {
    const msg = asMessage(raw)
    if (!msg) return
    if (watchedId.value && msg.conversationId !== watchedId.value) return
    if (liveMessages.value.some((m) => m.id === msg.id)) return
    liveMessages.value = [...liveMessages.value, msg]
  }

  function clearLiveMessages() {
    liveMessages.value = []
  }

  async function reload() {
    const res = await get<{ items?: CsConversation[] }>('/api/admin/cs/conversations')
    conversations.value = (res.items || [])
      .map((x) => asConversation(x))
      .filter((x): x is CsConversation => !!x)
  }

  function stopReconnectTimer() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
  }

  function killSource() {
    const prev = source
    source = null
    if (!prev) return
    prev.onopen = null
    prev.onmessage = null
    prev.onerror = null
    prev.close()
  }

  function handlePayload(data: {
    type?: string
    item?: Partial<CsMessage> | Partial<CsConversation>
    conversation?: Partial<CsConversation>
  }) {
    if (data.type === 'ready' || data.type === 'ping') {
      wsStatus.value = 'live'
      backoffMs = 2000
      return
    }
    if (data.type === 'message' && data.item) {
      pushLiveMessage(data.item as Partial<CsMessage>)
      if (data.conversation) upsertConversation(data.conversation)
    } else if (data.type === 'conversation' && data.item) {
      upsertConversation(data.item as Partial<CsConversation>)
    }
  }

  function scheduleReconnect() {
    if (!alive) return
    wsStatus.value = 'retry'
    if (reconnectTimer) return
    const wait = backoffMs
    backoffMs = Math.min(Math.round(backoffMs * 1.5), 15000)
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, wait)
  }

  function connect() {
    if (!alive) return
    if (source && source.readyState !== EventSource.CLOSED) return
    if (reconnectTimer) return

    const myGen = ++gen
    killSource()
    const url = csEventsUrl()
    if (!url.includes('token=')) {
      wsStatus.value = 'off'
      return
    }

    wsStatus.value = 'connecting'
    let es: EventSource
    try {
      es = new EventSource(url)
    } catch {
      scheduleReconnect()
      return
    }
    source = es

    es.onopen = () => {
      if (myGen !== gen || source !== es) return
      // 等服务端 ready；onopen 只表示 HTTP 流已建立
    }

    es.onmessage = (ev) => {
      if (myGen !== gen || source !== es) return
      try {
        handlePayload(JSON.parse(String(ev.data || '{}')))
      } catch {
        /* ignore */
      }
    }

    es.onerror = () => {
      if (myGen !== gen) return
      killSource()
      scheduleReconnect()
    }
  }

  function watchConversation(cid: string) {
    watchedId.value = cid || ''
  }

  function start(hasPerm: boolean) {
    if (!hasPerm) return
    if (alive) {
      if (!source || source.readyState === EventSource.CLOSED) connect()
      return
    }
    alive = true
    backoffMs = 2000
    void reload().catch(() => undefined)
    connect()
    pollTimer = setInterval(() => {
      if (!alive) return
      void reload().catch(() => undefined)
    }, 15000)
  }

  function stop() {
    alive = false
    stopReconnectTimer()
    if (pollTimer) {
      clearInterval(pollTimer)
      pollTimer = null
    }
    gen += 1
    killSource()
    wsStatus.value = 'off'
  }

  return {
    conversations,
    liveMessages,
    watchedId,
    wsStatus,
    unreadTotal,
    reload,
    upsertConversation,
    pushLiveMessage,
    clearLiveMessages,
    watchConversation,
    start,
    stop,
  }
})
