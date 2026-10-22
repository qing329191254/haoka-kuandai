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

  function stopPing() {
    if (pingTimer) {
      clearInterval(pingTimer)
      pingTimer = null
    }
  }

  function stopReconnectTimer() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
  }

  function markLive(ws: WebSocket, myGen: number) {
    if (myGen !== gen || socket !== ws) return
    backoffMs = 2000
    wsStatus.value = 'live'
    stopPing()
    pingTimer = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({ type: 'ping' }))
        } catch {
          /* ignore */
        }
      }
    }, 25000)
    if (watchedId.value) {
      try {
        ws.send(JSON.stringify({ type: 'watch', conversationId: watchedId.value }))
      } catch {
        /* ignore */
      }
    }
  }

  function scheduleReconnect() {
    if (!alive) return
    wsStatus.value = 'retry'
    if (reconnectTimer) return
    const wait = backoffMs
    backoffMs = Math.min(backoffMs * 1.6, 20000)
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, wait)
  }

  function detachSocket(ws: WebSocket | null) {
    if (!ws) return
    ws.onopen = null
    ws.onmessage = null
    ws.onerror = null
    ws.onclose = null
  }

  function connect() {
    if (!alive) return
    // 已连通或正在连，勿重复建连（避免自杀式重连风暴）
    if (
      socket &&
      (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)
    ) {
      return
    }

    stopReconnectTimer()
    stopPing()
    const myGen = ++gen

    detachSocket(socket)
    try {
      socket?.close()
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
    let ws: WebSocket
    try {
      ws = new WebSocket(url)
    } catch {
      scheduleReconnect()
      return
    }
    socket = ws

    ws.onopen = () => {
      markLive(ws, myGen)
    }

    ws.onmessage = (ev) => {
      if (myGen !== gen || socket !== ws) return
      try {
        const data = JSON.parse(String(ev.data || '{}')) as {
          type?: string
          item?: Partial<CsMessage> | Partial<CsConversation>
          conversation?: Partial<CsConversation>
        }
        // 服务端 ready 也视为已连通（防止个别环境 onopen 异常）
        if (data.type === 'ready' || data.type === 'pong' || data.type === 'watched') {
          if (wsStatus.value !== 'live') markLive(ws, myGen)
          return
        }
        if (data.type === 'message' && data.item) {
          pushLiveMessage(data.item as Partial<CsMessage>)
          if (data.conversation) upsertConversation(data.conversation)
        } else if (data.type === 'conversation' && data.item) {
          upsertConversation(data.item as Partial<CsConversation>)
        }
      } catch {
        /* ignore malformed frames */
      }
    }

    // 不要在 onerror 里主动 close：部分代理会误触发 error，主动 close 会变成重连风暴
    ws.onerror = () => {
      /* onclose 会跟进 */
    }

    ws.onclose = () => {
      if (myGen !== gen) return
      stopPing()
      if (socket === ws) socket = null
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
    if (!hasPerm) return
    if (alive) {
      // 布局已启动过：仅确保连着
      if (!socket || socket.readyState === WebSocket.CLOSED) connect()
      return
    }
    alive = true
    backoffMs = 2000
    void reload().catch(() => undefined)
    connect()
    // WS 异常时兜底拉列表，避免角标长期卡住
    pollTimer = setInterval(() => {
      if (!alive) return
      if (wsStatus.value === 'live') return
      void reload().catch(() => undefined)
      // 卡住在 connecting 过久时再试一次
      if (
        wsStatus.value === 'connecting' ||
        wsStatus.value === 'retry' ||
        wsStatus.value === 'off'
      ) {
        if (!socket || socket.readyState === WebSocket.CLOSED) connect()
      }
    }, 15000)
  }

  function stop() {
    alive = false
    stopReconnectTimer()
    stopPing()
    if (pollTimer) {
      clearInterval(pollTimer)
      pollTimer = null
    }
    gen += 1
    detachSocket(socket)
    try {
      socket?.close()
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
