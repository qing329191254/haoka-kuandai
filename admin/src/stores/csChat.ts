import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { csWsUrl, get } from '@/api/http'

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

/** 后台客服实时通道：布局层常驻，列表页共用。 */
export const useCsChatStore = defineStore('csChat', () => {
  const conversations = ref<CsConversation[]>([])
  const liveMessages = ref<CsMessage[]>([])
  const watchedId = ref('')
  const wsStatus = ref<'off' | 'connecting' | 'live' | 'retry'>('off')

  let socket: WebSocket | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let pingTimer: ReturnType<typeof setInterval> | null = null
  let pollTimer: ReturnType<typeof setInterval> | null = null
  let alive = false
  let gen = 0

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

  function stopTimers() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    if (pingTimer) {
      clearInterval(pingTimer)
      pingTimer = null
    }
  }

  function scheduleReconnect() {
    if (!alive) return
    wsStatus.value = 'retry'
    if (reconnectTimer) return
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, 2500)
  }

  function connect() {
    if (!alive) return
    stopTimers()
    const myGen = ++gen
    try {
      if (socket) {
        socket.onopen = null
        socket.onmessage = null
        socket.onerror = null
        socket.onclose = null
        socket.close()
      }
    } catch {
      /* ignore */
    }
    socket = null

    const url = csWsUrl()
    if (!url.includes('token=')) {
      wsStatus.value = 'off'
      return
    }

    wsStatus.value = 'connecting'
    const ws = new WebSocket(url)
    socket = ws

    ws.onopen = () => {
      if (myGen !== gen) return
      wsStatus.value = 'live'
      pingTimer = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'ping' }))
        }
      }, 25000)
      if (watchedId.value) {
        ws.send(JSON.stringify({ type: 'watch', conversationId: watchedId.value }))
      }
    }

    ws.onmessage = (ev) => {
      if (myGen !== gen) return
      try {
        const data = JSON.parse(String(ev.data || '{}')) as {
          type?: string
          item?: Partial<CsMessage> | Partial<CsConversation>
          conversation?: Partial<CsConversation>
        }
        if (data.type === 'message' && data.item) {
          pushLiveMessage(data.item as Partial<CsMessage>)
          if (data.conversation) upsertConversation(data.conversation)
        } else if (data.type === 'conversation' && data.item) {
          upsertConversation(data.item as Partial<CsConversation>)
        }
      } catch {
        /* ignore */
      }
    }

    ws.onerror = () => {
      if (myGen !== gen) return
      try {
        ws.close()
      } catch {
        /* ignore */
      }
    }

    ws.onclose = () => {
      if (myGen !== gen) return
      stopTimers()
      socket = null
      scheduleReconnect()
    }
  }

  function watchConversation(cid: string) {
    watchedId.value = cid || ''
    if (socket?.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: 'watch', conversationId: watchedId.value }))
    }
  }

  function start(hasPerm: boolean) {
    if (!hasPerm || alive) return
    alive = true
    void reload().catch(() => undefined)
    connect()
    // WS 异常时兜底，避免角标长期卡住
    pollTimer = setInterval(() => {
      if (!alive) return
      if (wsStatus.value === 'live') return
      void reload().catch(() => undefined)
    }, 12000)
  }

  function stop() {
    alive = false
    stopTimers()
    if (pollTimer) {
      clearInterval(pollTimer)
      pollTimer = null
    }
    gen += 1
    try {
      if (socket) {
        socket.onopen = null
        socket.onmessage = null
        socket.onerror = null
        socket.onclose = null
        socket.close()
      }
    } catch {
      /* ignore */
    }
    socket = null
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
