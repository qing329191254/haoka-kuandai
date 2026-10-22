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

/** 后台客服：WS 优先；失败时 HTTP 轮询兜底，避免重连风暴掐断已连上的 socket。 */
export const useCsChatStore = defineStore('csChat', () => {
  const conversations = ref<CsConversation[]>([])
  const liveMessages = ref<CsMessage[]>([])
  const watchedId = ref('')
  const wsStatus = ref<'off' | 'connecting' | 'live' | 'retry'>('off')

  let socket: WebSocket | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let stuckTimer: ReturnType<typeof setTimeout> | null = null
  let pingTimer: ReturnType<typeof setInterval> | null = null
  let pollTimer: ReturnType<typeof setInterval> | null = null
  let alive = false
  let gen = 0
  let backoffMs = 4000

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

  function stopStuckTimer() {
    if (stuckTimer) {
      clearTimeout(stuckTimer)
      stuckTimer = null
    }
  }

  function stopReconnectTimer() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
  }

  function isBusy() {
    return (
      !!socket &&
      (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)
    )
  }

  function markLive(ws: WebSocket, myGen: number) {
    if (myGen !== gen || socket !== ws) return
    if (ws.readyState !== WebSocket.OPEN) return
    stopReconnectTimer()
    stopStuckTimer()
    backoffMs = 4000
    wsStatus.value = 'live'
    stopPing()
    try {
      ws.send(JSON.stringify({ type: 'ping' }))
    } catch {
      /* ignore */
    }
    pingTimer = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({ type: 'ping' }))
        } catch {
          /* ignore */
        }
      }
    }, 20000)
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
    if (reconnectTimer || isBusy()) return
    const wait = backoffMs
    backoffMs = Math.min(Math.round(backoffMs * 1.6), 30000)
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, wait)
  }

  function killSocket() {
    stopStuckTimer()
    stopPing()
    const prev = socket
    socket = null
    if (!prev) return
    prev.onopen = null
    prev.onmessage = null
    prev.onerror = null
    prev.onclose = null
    try {
      prev.close()
    } catch {
      /* ignore */
    }
  }

  function connect() {
    if (!alive) return
    // 已有连接或正在连：绝不强行掐线重开（这是之前重连风暴的根因）
    if (isBusy()) return
    if (reconnectTimer) return

    stopPing()
    const myGen = ++gen
    killSocket()

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

    stuckTimer = setTimeout(() => {
      if (myGen !== gen || socket !== ws) return
      if (ws.readyState === WebSocket.CONNECTING) {
        try {
          ws.close()
        } catch {
          /* ignore */
        }
      }
    }, 15000)

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
        if (data.type === 'ready' || data.type === 'pong' || data.type === 'ping' || data.type === 'watched') {
          markLive(ws, myGen)
          if (data.type === 'ping') {
            try {
              ws.send(JSON.stringify({ type: 'pong' }))
            } catch {
              /* ignore */
            }
          }
          return
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
      /* 只靠 onclose 重连，避免 error+close 双触发 */
    }

    ws.onclose = () => {
      stopStuckTimer()
      if (myGen !== gen) return
      stopPing()
      if (socket === ws) socket = null
      scheduleReconnect()
    }
  }

  function watchConversation(cid: string) {
    watchedId.value = cid || ''
    if (socket?.readyState === WebSocket.OPEN) {
      try {
        socket.send(JSON.stringify({ type: 'watch', conversationId: watchedId.value }))
      } catch {
        /* ignore */
      }
    }
  }

  function start(hasPerm: boolean) {
    if (!hasPerm) return
    if (alive) {
      if (!isBusy() && !reconnectTimer) connect()
      return
    }
    alive = true
    backoffMs = 4000
    void reload().catch(() => undefined)
    connect()
    // 列表/角标：WS 通时 20s 拉一次；不通时 5s，保证功能可用
    pollTimer = setInterval(() => {
      if (!alive) return
      void reload().catch(() => undefined)
      if (wsStatus.value !== 'live' && !isBusy() && !reconnectTimer) {
        connect()
      }
    }, 5000)
  }

  function stop() {
    alive = false
    stopReconnectTimer()
    stopStuckTimer()
    stopPing()
    if (pollTimer) {
      clearInterval(pollTimer)
      pollTimer = null
    }
    gen += 1
    killSocket()
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
