import type { BizType, MpOrder, OrderStatus } from '@/types/order'

/** 按关键词匹配订单（单号 / 客户 / 电话 / 地址 / 产品 / 师傅） */
export function matchOrderKeyword(o: MpOrder, keyword: string): boolean {
  const q = keyword.trim().toLowerCase()
  if (!q) return true
  const hay = [
    o.orderNo,
    o.customerName,
    o.customerPhone,
    o.address,
    o.productName,
    o.carrier,
    o.technicianName || '',
    o.merchantName || '',
    o.assignedMerchantName || '',
    o.stockTypeName || '',
    o.failReason || '',
    o.followUpReason || '',
  ]
    .join(' ')
    .toLowerCase()
  return hay.includes(q)
}

export function filterOrders(
  list: MpOrder[],
  opts: {
    keyword?: string
    bizType?: BizType | 'all'
    groupKey?: string
    status?: OrderStatus | 'all'
    statuses?: OrderStatus[]
  },
): MpOrder[] {
  const biz = opts.bizType && opts.bizType !== 'all' ? opts.bizType : null
  const status = opts.status && opts.status !== 'all' ? opts.status : null
  const statusSet = opts.statuses?.length ? new Set(opts.statuses) : null
  const groupKey = opts.groupKey && opts.groupKey !== 'all' ? opts.groupKey : null

  return list.filter((o) => {
    if (!matchOrderKeyword(o, opts.keyword || '')) return false
    if (biz && o.bizType !== biz) return false
    if (groupKey) {
      const key = o.bizType === 'stock' ? `stock:${o.stockTypeId || 'other'}` : o.bizType
      if (key !== groupKey) return false
    }
    if (status && o.status !== status) return false
    if (statusSet && !statusSet.has(o.status)) return false
    return true
  })
}

/** 新单在前 */
export function sortOrdersByTime(list: MpOrder[]): MpOrder[] {
  return [...list].sort((a, b) => (a.createdAt < b.createdAt ? 1 : a.createdAt > b.createdAt ? -1 : 0))
}
