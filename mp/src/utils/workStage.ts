import { skipTechDispatch, type MpOrder, type OrderStatus } from '@/types/order'

/** 商家工作台阶段：录入 / 办理 / 派单上门 */
export type WorkStage = 'entry' | 'process' | 'dispatch'

export const WORK_STAGE_TITLE: Record<WorkStage, string> = {
  entry: '订单录入',
  process: '订单办理',
  dispatch: '派单上门',
}

export function parseWorkStage(v?: string): WorkStage {
  if (v === 'process' || v === 'dispatch') return v
  return 'entry'
}

/** 订单是否属于某工作台阶段 */
export function orderInStage(o: MpOrder, stage: WorkStage): boolean {
  if (o.status === 'done' || o.status === 'cancelled') return false

  switch (stage) {
    case 'entry':
      return o.status === 'listed'
    case 'process':
      if (o.status === 'follow_up' || o.status === 'failed') return true
      if (skipTechDispatch(o.bizType)) {
        return ['merchant_accepted', 'boss_opened', 'installing'].includes(o.status)
      }
      return o.status === 'merchant_accepted' && !o.needsDispatch
    case 'dispatch':
      if (skipTechDispatch(o.bizType)) return false
      if (o.status === 'merchant_accepted' && o.needsDispatch) return true
      return ['dispatched', 'tech_accepted', 'boss_opened', 'installing'].includes(o.status)
    default:
      return false
  }
}

export function stageTabCounts(orders: MpOrder[], stage: WorkStage) {
  const scoped = orders.filter((o) => orderInStage(o, stage))
  if (stage === 'entry') {
    return { pending: scoped.length, mine: 0, done: 0, follow: 0 }
  }
  if (stage === 'process') {
    const follow = scoped.filter((o) => o.status === 'follow_up' || o.status === 'failed').length
    const mine = scoped.length - follow
    return { pending: 0, mine, done: 0, follow }
  }
  // dispatch
  const pending = scoped.filter((o) => o.status === 'merchant_accepted' && o.needsDispatch).length
  const mine = scoped.filter((o) =>
    ['dispatched', 'tech_accepted', 'boss_opened', 'installing'].includes(o.status),
  ).length
  return { pending, mine, done: 0, follow: 0 }
}

export const DISPATCH_STATUSES: OrderStatus[] = [
  'dispatched',
  'tech_accepted',
  'boss_opened',
  'installing',
]
