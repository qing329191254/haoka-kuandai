import { request } from '@/api/http'
import { getSession } from '@/store/session'
import { skipTechDispatch, type MpOrder } from '@/types/order'

export interface MerchantStats {
  entry: number
  process: number
  dispatch: number
  followUp: number
  done: number
}

let cache: MpOrder[] = []

export async function refreshOrders() {
  const s = getSession()
  if (!s) {
    cache = []
    return cache
  }
  try {
    if (s.role === 'merchant') {
      const data = await request<{ items: MpOrder[] }>({ url: '/api/mp/orders' })
      cache = data.items || []
    } else {
      const data = await request<{ items: MpOrder[] }>({ url: '/api/mp/tech/orders' })
      cache = data.items || []
    }
  } catch {
    /* 保留已有列表，避免操作成功后因刷新失败被清空 */
  }
  return cache
}

export function listOrders() {
  return cache
}

export function getOrder(id: string) {
  return cache.find((o) => o.id === id)
}

function upsertCache(o: MpOrder) {
  const i = cache.findIndex((x) => x.id === o.id)
  if (i >= 0) cache[i] = o
  else cache.unshift(o)
}

export async function fetchOrder(id: string) {
  try {
    const o = await request<MpOrder>({ url: `/api/mp/orders/${id}` })
    upsertCache(o)
    return o
  } catch {
    return getOrder(id)
  }
}

export async function listTechnicians() {
  const data = await request<{ items: { id: string; name: string; phone: string }[] }>({ url: '/api/mp/technicians' })
  return data.items || []
}

async function act(url: string, data?: unknown) {
  const o = await request<MpOrder>({ url, method: 'POST', data })
  upsertCache(o)
  return true
}

export async function acceptByMerchant(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/accept`)
  } catch {
    return false
  }
}

export async function merchantCompleteRemote(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/complete-remote`)
  } catch {
    return false
  }
}

export async function merchantMarkNeedsDispatch(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/needs-dispatch`)
  } catch {
    return false
  }
}

export async function merchantMarkFollowUp(id: string, reason: string, nextAt?: string, note?: string) {
  try {
    return await act(`/api/mp/orders/${id}/follow-up`, { reason, nextAt, note })
  } catch {
    return false
  }
}

export async function merchantResumeProcessing(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/resume`)
  } catch {
    return false
  }
}

export async function merchantCancelOrder(id: string, reason?: string) {
  try {
    return await act(`/api/mp/orders/${id}/cancel`, { reason, remark: reason })
  } catch {
    return false
  }
}

export async function dispatchToTech(id: string, technicianName: string, technicianId?: string) {
  try {
    return await act(`/api/mp/orders/${id}/dispatch`, { technicianName, technicianId })
  } catch {
    return false
  }
}

export async function merchantBossPcOpen(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/boss-pc`)
  } catch {
    return false
  }
}

export async function markInstallDone(id: string) {
  try {
    return await act(`/api/mp/orders/${id}/install-done`)
  } catch {
    return false
  }
}

export async function techAccept(id: string) {
  try {
    return await act(`/api/mp/tech/orders/${id}/accept`)
  } catch {
    return false
  }
}

export async function techBossMobileOpen(id: string) {
  try {
    return await act(`/api/mp/tech/orders/${id}/boss-open`)
  } catch {
    return false
  }
}

export function canDeliver(o: MpOrder) {
  if (['done', 'failed', 'cancelled', 'listed', 'merchant_accepted', 'dispatched'].includes(o.status)) return false
  if (o.bizType === 'broadband_new_card') return o.status === 'boss_opened' || o.status === 'installing'
  if (o.bizType === 'haoka') return o.status === 'boss_opened'
  return o.status === 'tech_accepted'
}

export async function techDeliverSuccess(id: string, photos: string[]) {
  try {
    return await act(`/api/mp/tech/orders/${id}/deliver-ok`, { photos })
  } catch {
    return false
  }
}

export async function techDeliverFail(id: string, reason: string) {
  try {
    return await act(`/api/mp/tech/orders/${id}/deliver-fail`, { reason })
  } catch {
    return false
  }
}

export async function merchantStats(): Promise<MerchantStats> {
  try {
    return await request<MerchantStats>({ url: '/api/mp/stats' })
  } catch {
    return { entry: 0, process: 0, dispatch: 0, followUp: 0, done: 0 }
  }
}

export async function techStats() {
  try {
    return await request<{ todo: number; serving: number; done: number; returned: number }>({ url: '/api/mp/tech/stats' })
  } catch {
    return { todo: 0, serving: 0, done: 0, returned: 0 }
  }
}

export async function techBizGroups() {
  await refreshOrders()
  const all = cache
  const defs: { key: string; label: string }[] = [
    { key: 'haoka', label: '号卡' },
    { key: 'contract_phone', label: '合约机' },
    { key: 'broadband_new_card', label: '融合宽带（新开卡）' },
    { key: 'wifi', label: 'WIFI 设备' },
    { key: 'cpe', label: 'CPE' },
    { key: 'stock:st1', label: '宽带续费' },
    { key: 'stock:st2', label: '套餐升档' },
    { key: 'stock:st3', label: 'IPTV / 电视增值' },
  ]
  return defs.map((d) => {
    const list = all.filter((o) => {
      const key = o.bizType === 'stock' ? `stock:${o.stockTypeId || 'other'}` : o.bizType
      return key === d.key
    })
    return {
      ...d,
      todo: list.filter((o) => o.status === 'dispatched').length,
      serving: list.filter((o) => ['tech_accepted', 'boss_opened', 'installing'].includes(o.status)).length,
      done: list.filter((o) => o.status === 'done').length,
      returned: list.filter((o) => o.status === 'failed' || o.status === 'follow_up').length,
      total: list.length,
    }
  })
}

export { skipTechDispatch }
