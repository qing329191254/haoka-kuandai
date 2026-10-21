import type { EnableStatus } from '@/types/order'

/** 平台合作代理（App 入驻审核通过后写入） */
export interface Agent {
  id: string
  /** 公司 / 门店名称 */
  name: string
  phone: string
  contact: string
  province: string
  city: string
  district: string
  address?: string
  wechat?: string
  backupPhone?: string
  /** 身份证号或统一社会信用代码 */
  idNo?: string
  /** 证件文件名（演示） */
  licenseName?: string
  joinedAt: string
  orderCount: number
  status: EnableStatus
  remark?: string
}

export const SCALE_OPTIONS = [
  { id: 'county', label: '区县级' },
  { id: 'city', label: '地市级' },
  { id: 'province', label: '省级' },
] as const

export type AgentScale = (typeof SCALE_OPTIONS)[number]['id']

export type AgentApplyStatus = 'pending' | 'approved' | 'rejected'

/** 按城市 + 合作规模配置入驻押金 */
export interface DepositRule {
  id: string
  province: string
  city: string
  scale: AgentScale | string
  scaleLabel?: string
  amount: number
  remark: string
  status: EnableStatus
  scope?: string
}

/** App 提交的入驻申请（含押金与电子签） */
export interface AgentApplication {
  id: string
  phone: string
  contact: string
  name: string
  province: string
  city: string
  district: string
  address: string
  wechat: string
  backupPhone: string
  idNo: string
  licenseName: string
  remark: string
  status: AgentApplyStatus
  rejectReason?: string
  createdAt: string
  reviewedAt?: string
  /** 通过后关联的代理商 id */
  agentId?: string
  scale?: string
  scaleLabel?: string
  /** 应缴押金（元） */
  depositAmount: number
  depositPaid: boolean
  depositPaidAt?: string
  contractSigned: boolean
  contractSignedAt?: string
  contractNo?: string
  signerName?: string
}

export function agentRegionLabel(a: Pick<Agent | AgentApplication, 'province' | 'city' | 'district'>) {
  return [a.province, a.city, a.district].filter(Boolean).join(' ')
}

export interface WarehouseItem {
  id: string
  productId: string
  productName: string
  sku: string
  spec: string
  stock: number
  safetyStock: number
  location: string
  updatedAt: string
}

export type StockType = 'in' | 'out'

export interface StockRecord {
  id: string
  type: StockType
  warehouseId: string
  productId: string
  productName: string
  sku: string
  qty: number
  orderNo?: string
  operator: string
  remark?: string
  createdAt: string
}
