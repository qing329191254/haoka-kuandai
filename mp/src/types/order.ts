export type BizType =
  | 'haoka'
  | 'contract_phone'
  | 'broadband_naked'
  | 'broadband_new_card'
  | 'broadband_no_card'
  | 'wifi'
  | 'cpe'
  | 'stock'
export type Role = 'merchant' | 'technician'

export type OrderStatus =
  | 'listed'
  | 'merchant_accepted'
  | 'dispatched'
  | 'tech_accepted'
  | 'boss_opened'
  | 'installing'
  | 'follow_up'
  | 'done'
  | 'failed'
  | 'cancelled'

export interface FollowUpLog {
  time: string
  note: string
  actor?: string
}

export interface MpOrder {
  id: string
  orderNo: string
  bizType: BizType
  status: OrderStatus
  customerName: string
  customerPhone: string
  address: string
  productName: string
  carrier: string
  needNewCard: boolean
  assignedMerchantId?: string
  assignedMerchantName?: string
  merchantName?: string
  technicianName?: string
  createdAt: string
  remark?: string
  stockTypeId?: string
  stockTypeName?: string
  failReason?: string
  /** 客服已确认需上门，进入派单上门环节 */
  needsDispatch?: boolean
  /** 待跟进原因 */
  followUpReason?: string
  /** 下次联系时间 */
  nextFollowUpAt?: string
  followUpLogs?: FollowUpLog[]
  deliveryPhotos?: string[]
  orderIntent?: string
  phoneBrand?: string
  priceRange?: string
  wifiDeviceType?: string
  wifiBizMode?: string
}

export const BIZ_TYPE_LABEL: Record<BizType, string> = {
  haoka: '号卡',
  contract_phone: '合约机',
  broadband_naked: '裸宽',
  broadband_new_card: '融合宽带（新开卡）',
  broadband_no_card: '融合宽带（线上办理）',
  wifi: 'WIFI 设备',
  cpe: 'CPE',
  stock: '存量业务',
}

export function orderBizLabel(o: Pick<MpOrder, 'bizType' | 'stockTypeName'>) {
  if (o.bizType === 'stock' && o.stockTypeName) return o.stockTypeName
  return BIZ_TYPE_LABEL[o.bizType]
}

export function orderGroupKey(o: Pick<MpOrder, 'bizType' | 'stockTypeId'>) {
  if (o.bizType === 'stock') return `stock:${o.stockTypeId || 'other'}`
  return o.bizType
}

/** 裸宽、融合线上办理：不派师傅上门 */
export function skipTechDispatch(bizType: BizType) {
  return bizType === 'broadband_no_card' || bizType === 'broadband_naked'
}

/** 与 App 端状态语义对齐（B 端可略偏操作视角） */
export const STATUS_LABEL: Record<OrderStatus, string> = {
  listed: '待接单',
  merchant_accepted: '商家处理中',
  dispatched: '待上门',
  tech_accepted: '上门服务中',
  boss_opened: '已开户',
  installing: '装机中',
  follow_up: '跟进中',
  done: '已完成',
  failed: '跟进中',
  cancelled: '已取消',
}

export const ROLE_LABEL: Record<Role, string> = {
  merchant: '商家',
  technician: '上门师傅',
}
