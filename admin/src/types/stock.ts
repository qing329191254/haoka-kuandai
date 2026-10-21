import type { EnableStatus } from '@/types/order'
import { extraAgents, extraStock, extraWarehouse } from '@/mock/bulk'

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

export const mockAgents: Agent[] = [
  {
    id: 'a1',
    name: '杭州星链代理点',
    phone: '13800138000',
    contact: '张代理',
    province: '浙江省',
    city: '杭州市',
    district: '西湖区',
    address: '文三路100号',
    wechat: 'zl_agent01',
    backupPhone: '0571-88881234',
    idNo: '330106199001011234',
    licenseName: 'demo_license.jpg',
    joinedAt: '2026-08-01 10:00:00',
    orderCount: 12,
    status: 'active',
    remark: '演示已通过账号',
  },
  {
    id: 'a2',
    name: '李四号卡代理',
    phone: '13900002222',
    contact: '李四',
    province: '浙江省',
    city: '杭州市',
    district: '余杭区',
    address: '文一西路66号',
    wechat: 'lisi_agent',
    idNo: '330110199103031234',
    licenseName: 'license_a2.jpg',
    joinedAt: '2026-08-03 11:20:00',
    orderCount: 5,
    status: 'active',
  },
  {
    id: 'a3',
    name: '王五宽带代理',
    phone: '13700003333',
    contact: '王五',
    province: '浙江省',
    city: '杭州市',
    district: '滨江区',
    address: '网商路8号',
    joinedAt: '2026-08-05 09:12:00',
    orderCount: 3,
    status: 'active',
  },
  ...extraAgents(),
]

export const mockAgentApplications: AgentApplication[] = [
  {
    id: 'ap1',
    phone: '13900139000',
    contact: '李申请',
    name: '南京拓客通讯',
    province: '江苏省',
    city: '南京市',
    district: '鼓楼区',
    address: '中山路88号',
    wechat: 'nj_tuoke',
    backupPhone: '',
    idNo: '320106199202021234',
    licenseName: 'demo_license2.jpg',
    remark: '希望合作宽带业务',
    status: 'pending',
    createdAt: '2026-08-20 14:20:00',
    depositAmount: 5000,
    depositPaid: true,
    depositPaidAt: '2026-08-20 14:30:00',
    contractSigned: true,
    contractSignedAt: '2026-08-20 14:45:00',
    contractNo: 'HT20260820001',
    signerName: '李申请',
  },
  {
    id: 'ap2',
    phone: '13600136000',
    contact: '赵渠道',
    name: '苏州渠道工作室',
    province: '江苏省',
    city: '苏州市',
    district: '姑苏区',
    address: '干将东路12号',
    wechat: 'sz_qd',
    backupPhone: '0512-88880001',
    idNo: '91320500MA1XXXXX1X',
    licenseName: 'biz_license_sz.jpg',
    remark: '已签合同，App 待交押金（演示）',
    status: 'pending',
    createdAt: '2026-08-21 09:10:00',
    depositAmount: 5000,
    depositPaid: false,
    contractSigned: true,
    contractSignedAt: '2026-08-21 09:20:00',
    contractNo: 'HT20260821001',
    signerName: '赵渠道',
  },
  {
    id: 'ap3',
    phone: '13700137000',
    contact: '王某',
    name: '资料不全门店',
    province: '广东省',
    city: '广州市',
    district: '天河区',
    address: '天河路1号',
    wechat: '',
    backupPhone: '',
    idNo: '',
    licenseName: '',
    remark: '',
    status: 'rejected',
    rejectReason: '证件信息不清晰，请重新上传后再次申请',
    createdAt: '2026-08-18 16:40:00',
    reviewedAt: '2026-08-19 10:00:00',
    depositAmount: 5000,
    depositPaid: true,
    depositPaidAt: '2026-08-18 17:00:00',
    contractSigned: true,
    contractSignedAt: '2026-08-18 17:20:00',
    contractNo: 'HT20260818001',
    signerName: '王某',
  },
  {
    id: 'ap4',
    phone: '13800138000',
    contact: '张代理',
    name: '杭州星链代理点',
    province: '浙江省',
    city: '杭州市',
    district: '西湖区',
    address: '文三路100号',
    wechat: 'zl_agent01',
    backupPhone: '0571-88881234',
    idNo: '330106199001011234',
    licenseName: 'demo_license.jpg',
    remark: '演示已通过账号',
    status: 'approved',
    createdAt: '2026-07-28 09:00:00',
    reviewedAt: '2026-08-01 10:00:00',
    agentId: 'a1',
    depositAmount: 5000,
    depositPaid: true,
    depositPaidAt: '2026-07-28 10:00:00',
    contractSigned: true,
    contractSignedAt: '2026-07-28 10:15:00',
    contractNo: 'HT20260728001',
    signerName: '张代理',
  },
  {
    id: 'ap5',
    phone: '13500135000',
    contact: '钱拓展',
    name: '无锡拓展通讯',
    province: '江苏省',
    city: '无锡市',
    district: '梁溪区',
    address: '中山路1号',
    wechat: '',
    backupPhone: '',
    idNo: '320200199501011111',
    licenseName: 'license_wx.jpg',
    remark: 'App 待签合同（演示）',
    status: 'pending',
    createdAt: '2026-08-21 11:00:00',
    depositAmount: 5000,
    depositPaid: false,
    contractSigned: false,
  },
]

export const mockWarehouse: WarehouseItem[] = [
  {
    id: 'w1',
    productId: 'p1',
    productName: '电信畅享卡 59元',
    sku: 'HK-DX-59',
    spec: '号卡实体卡',
    stock: 120,
    safetyStock: 30,
    location: '杭州仓-A1',
    updatedAt: '2026-08-20 09:00:00',
  },
  {
    id: 'w2',
    productId: 'p2',
    productName: '移动青春卡 39元',
    sku: 'HK-YD-39',
    spec: '号卡实体卡',
    stock: 18,
    safetyStock: 40,
    location: '杭州仓-A2',
    updatedAt: '2026-08-20 09:10:00',
  },
  {
    id: 'w3',
    productId: 'p3',
    productName: '联通大王卡 29元',
    sku: 'HK-LT-29',
    spec: '号卡实体卡',
    stock: 86,
    safetyStock: 25,
    location: '杭州仓-B1',
    updatedAt: '2026-08-19 18:20:00',
  },
  ...extraWarehouse(),
]

export const mockStockRecords: StockRecord[] = [
  {
    id: 'sr1',
    type: 'in',
    warehouseId: 'w1',
    productId: 'p1',
    productName: '电信畅享卡 59元',
    sku: 'HK-DX-59',
    qty: 50,
    operator: '仓管小周',
    remark: '号卡到货入库',
    createdAt: '2026-08-18 10:00:00',
  },
  {
    id: 'sr2',
    type: 'out',
    warehouseId: 'w1',
    productId: 'p1',
    productName: '电信畅享卡 59元',
    sku: 'HK-DX-59',
    qty: 2,
    orderNo: 'HK20260820001',
    operator: '客服小李',
    remark: '号卡订单出库',
    createdAt: '2026-08-20 09:30:00',
  },
  ...extraStock(),
]
