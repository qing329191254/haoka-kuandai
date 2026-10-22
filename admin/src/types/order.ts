/** 业务类型（三端统一） */
export type BizType =
  | 'haoka'
  | 'contract_phone'
  | 'broadband_naked'
  | 'broadband_new_card'
  | 'broadband_no_card'
  | 'wifi'
  | 'cpe'
  | 'stock'

/** 可上架套餐的业务（合约机不走套餐目录） */
export type ProductBizType =
  | 'haoka'
  | 'wifi'
  | 'cpe'
  | 'stock'
  | 'broadband_naked'
  | 'broadband_new_card'
  | 'broadband_no_card'

/** 订单状态（三端统一） */
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

export type Channel = 'app' | 'admin' | 'mp'

export type EnableStatus = 'active' | 'disabled'

export interface OrderLog {
  time: string
  actor: string
  action: string
  channel: Channel
}

export interface Order {
  id: string
  orderNo: string
  bizType: BizType
  status: OrderStatus
  customerName: string
  customerPhone: string
  address: string
  productName: string
  carrier: string
  merchantName?: string
  technicianName?: string
  needNewCard: boolean
  createdAt: string
  updatedAt: string
  remark?: string
  /** App 用户提交 */
  source: 'app'
  region: string
  logs: OrderLog[]
  /** 该单对应套餐佣金（元），随商品地区上架 */
  commission?: number
  /** 存量业务自定义类型 */
  stockTypeId?: string
  stockTypeName?: string
  /** 师傅交付失败原因，后台可见 */
  failReason?: string
  /** 客服已确认需上门 */
  needsDispatch?: boolean
  /** 待跟进原因 */
  followUpReason?: string
  /** 下次联系时间 */
  nextFollowUpAt?: string
  followUpLogs?: { time: string; note: string; actor?: string }[]
  /** 交付成功现场照片 */
  deliveryPhotos?: string[]
  /** 宽带：意向单 / 确定套餐 */
  orderIntent?: string
  /** 合约机 */
  phoneBrand?: string
  priceRange?: string
  /** WIFI 设备：4G / 5G */
  wifiDeviceType?: string
  /** WIFI 设备：买断 / 租赁 */
  wifiBizMode?: string
}

export interface Merchant {
  id: string
  name: string
  phone: string
  /** 与 App 选商家一致：按省 / 市覆盖，区用于同城优先展示 */
  province: string
  city: string
  district: string
  /** 门店详细地址（街道门牌），不参与按市筛选，供展示与联系 */
  address?: string
  status: EnableStatus
  /** 可接业务，对应小程序订单录入筛选 */
  bizTypes: BizType[]
  contact: string
  /** 小程序商家工作台展示名 */
  mpDisplayName: string
}

export type MerchantApplyStatus = 'pending' | 'approved' | 'rejected'

/** 本地商家入驻申请（小程序提交，后台审核） */
export interface MerchantApplication {
  id: string
  name: string
  phone: string
  contact: string
  province: string
  city: string
  district: string
  address: string
  wechat: string
  backupPhone: string
  idNo: string
  licenseName: string
  remark: string
  bizTypes: BizType[]
  status: MerchantApplyStatus
  rejectReason?: string
  createdAt: string
  reviewedAt?: string
  merchantId?: string
}

export function regionLabel(m: { province: string; city: string; district: string }) {
  return [m.province, m.city, m.district].filter(Boolean).join(' ')
}

export interface Technician {
  id: string
  name: string
  phone: string
  /** 与本地商家一致：上门服务省市区 */
  province: string
  city: string
  district: string
  status: EnableStatus
  merchantId: string
  merchantName: string
  /** 可接上门业务（裸宽 / 融合线上办理不派上门） */
  skills: Array<'haoka' | 'contract_phone' | 'broadband_new_card' | 'wifi' | 'cpe' | 'stock'>
}

/** 运营可自行新增的存量业务类型，其下再挂套餐 */
export interface StockBizType {
  id: string
  name: string
  description: string
  status: EnableStatus
  sort: number
}

export interface Product {
  id: string
  name: string
  bizType: ProductBizType
  /** 存量套餐所属自定义业务类型 */
  stockTypeId?: string
  /** 运营商或 WIFI 公司 */
  carrier: string
  priceLabel: string
  description: string
  status: EnableStatus
  /** 上架绑定地级市：同名套餐可按城市分别上架、分别设佣金 */
  province: string
  city: string
  /** 代理佣金（元） */
  commission: number
  /** WIFI 设备：4G / 5G */
  wifiDeviceType?: string
  /** WIFI 设备：买断 / 租赁 */
  wifiBizMode?: string
}

export interface AppUser {
  id: string
  nickname: string
  phone: string
  email: string
  gender: '保密' | '男' | '女'
  createdAt: string
  orderCount: number
  status: EnableStatus
}

export interface FaqItem {
  id: string
  category: '入驻' | '号卡' | '宽带' | '订单' | '账号'
  question: string
  answer: string
  enabled: boolean
  sort: number
}

export interface FeedbackItem {
  id: string
  type: '功能建议' | '体验问题' | '订单相关' | '入驻咨询' | '号卡/宽带' | '其他'
  content: string
  contact: string
  userName: string
  userId?: string
  channel?: 'app_feedback'
  createdAt: string
  status: 'pending' | 'handled'
  reply?: string
  adminNote?: string
  handledAt?: string
  handledBy?: string
}

export interface DocSection {
  heading: string
  body: string
}

export interface ContentDoc {
  id: 'agreement' | 'privacy' | 'help' | 'contract'
  title: string
  updatedAt: string
  sections: DocSection[]
}

export interface QuickReply {
  /** App「快捷问题」标签；点选后作为用户消息发送 */
  prompt: string
  /** 自动回复内容；留空则只发给人工 */
  reply: string
}

export interface ServiceConfig {
  hotline: string
  workTime: string
  quickReplies: QuickReply[]
}

export interface AppVersionConfig {
  latestVersion: string
  minSupportedVersion: string
  /** @deprecated 强制仅看 minSupportedVersion */
  forceUpdate: boolean
  title: string
  releaseNotes: string
  /** @deprecated Android 按包名跳商店，不再使用 */
  androidUrl: string
  /** iOS App Store 详情页，上架后填一次 */
  iosUrl: string
  enabled: boolean
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

export function labelBiz(type: string, stockTypeName?: string) {
  if (type === 'stock' && stockTypeName) return stockTypeName
  return BIZ_TYPE_LABEL[type as BizType] ?? type
}

export function productCityLabel(p: { province?: string; city?: string }) {
  return [p.province, p.city].filter(Boolean).join(' ')
}

export function orderBizLabel(o: { bizType: BizType; stockTypeName?: string }) {
  return labelBiz(o.bizType, o.stockTypeName)
}

export function labelCStatus(status: string) {
  return C_STATUS_LABEL[status as OrderStatus] ?? status
}

/** 运营后台状态文案 */
export const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  listed: '已上架',
  merchant_accepted: '商家已接单',
  dispatched: '已派单',
  tech_accepted: '师傅已接单',
  boss_opened: 'BOSS已开户',
  installing: '装机中',
  follow_up: '跟进中',
  done: '已完成',
  failed: '跟进中',
  cancelled: '已取消',
}

/** App / 小程序对客状态（两端已对齐） */
export const C_STATUS_LABEL: Record<OrderStatus, string> = {
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

export const CHANNEL_LABEL: Record<Channel, string> = {
  app: 'App',
  admin: '运营后台',
  mp: '小程序',
}

export const STATUS_TAG_TYPE: Record<OrderStatus, 'primary' | 'success' | 'warning' | 'info' | 'danger'> = {
  listed: 'primary',
  merchant_accepted: 'warning',
  dispatched: 'warning',
  tech_accepted: 'warning',
  boss_opened: 'warning',
  installing: 'warning',
  follow_up: 'warning',
  done: 'success',
  failed: 'warning',
  cancelled: 'info',
}

export type OrderGroup = 'all' | 'pending' | 'processing' | 'follow_up' | 'done' | 'failed' | 'cancelled'

export const ORDER_GROUP_LABEL: Record<OrderGroup, string> = {
  all: '全部',
  pending: '待接单',
  processing: '进行中',
  follow_up: '跟进中',
  done: '已完成',
  failed: '跟进中',
  cancelled: '已取消',
}

export function matchOrderGroup(status: OrderStatus, group: OrderGroup) {
  if (group === 'all') return true
  if (group === 'pending') return status === 'listed'
  if (group === 'done') return status === 'done'
  if (group === 'follow_up') return status === 'follow_up' || status === 'failed'
  if (group === 'failed') return status === 'failed'
  if (group === 'cancelled') return status === 'cancelled'
  return !['listed', 'done', 'follow_up', 'failed', 'cancelled'].includes(status)
}

/** 运营内部标准流程 */
export const FLOW_STEPS: Record<BizType, string[]> = {
  haoka: [
    'App 提交',
    '后台可见',
    '小程序商家接单并派单',
    '上门师傅接单上门',
    '运营商 BOSS 手机端开户激活',
    '完成',
  ],
  contract_phone: ['App 提交合约机意向', '后台可见', '小程序商家接单并派单', '上门师傅交付（拍照）', '完成'],
  broadband_naked: [
    'App 提交裸宽地址与联系方式',
    '后台可见',
    '小程序本地商家办理装机',
    '装机完成',
    '完成',
  ],
  broadband_new_card: [
    'App 提交',
    '后台可见',
    '小程序商家接单并派单',
    '上门师傅 BOSS 手机端开户',
    '装机师傅接运营商工单安装',
    '完成',
  ],
  broadband_no_card: [
    'App 提交',
    '后台可见',
    '小程序本地商家 BOSS 电脑端开户',
    '装机师傅接运营商工单安装',
    '完成',
  ],
  wifi: ['App 提交 WIFI 信息', '后台可见', '小程序商家接单并派单', '上门师傅交付（拍照）', '完成'],
  cpe: ['App 提交 CPE 信息', '后台可见', '小程序商家接单并派单', '上门师傅交付（拍照）', '完成'],
  stock: ['App 提交存量套餐', '后台可见', '小程序商家接单并派单', '上门师傅交付（拍照）', '完成'],
}

/** App 对客办理步骤（不出现后台/小程序内部词） */
export const C_FLOW_STEPS: Record<BizType, string[]> = {
  haoka: ['提交办卡信息', '商家接单安排', '师傅预约上门', '现场开户激活', '办理完成'],
  contract_phone: ['提交合约机意向', '分配当地商家', '商家接单联系', '交付办理', '办理完成'],
  broadband_naked: ['提交裸宽地址与联系方式', '分配当地商家', '商家办理装机', '安装完成'],
  broadband_new_card: ['提交融合宽带与开卡信息', '商家接单派单', '师傅上门开户', '安排装机上门', '安装完成'],
  broadband_no_card: ['提交融合宽带信息', '商家完成开户', '安排装机上门', '安装完成'],
  wifi: ['提交 WIFI 办理信息', '商家接单安排', '师傅预约上门', '现场交付拍照', '办理完成'],
  cpe: ['提交 CPE 办理信息', '商家接单安排', '师傅预约上门', '现场交付拍照', '办理完成'],
  stock: ['选择存量套餐', '商家接单安排', '师傅预约上门', '现场交付拍照', '办理完成'],
}

/** 小程序履约节点 */
export const MP_FLOW_NODES: Record<BizType, { role: string; action: string }[]> = {
  haoka: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → BOSS 手机端开户激活' },
  ],
  contract_phone: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → 交付成功上传照片 / 失败填写原因' },
  ],
  broadband_naked: [
    { role: '商家', action: '接单 → 办理装机 → 确认装机完成' },
    { role: '上门师傅', action: '无需派单（不进师傅任务）' },
  ],
  broadband_new_card: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → BOSS 手机端开户 → 确认装机完成' },
  ],
  broadband_no_card: [
    { role: '商家', action: '接单 → BOSS 电脑端开户 → 确认装机完成' },
    { role: '上门师傅', action: '无需派单（不进师傅任务）' },
  ],
  wifi: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → 交付成功上传照片 / 失败填写原因' },
  ],
  cpe: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → 交付成功上传照片 / 失败填写原因' },
  ],
  stock: [
    { role: '商家', action: '订单录入认领 → 订单办理 → 派单上门' },
    { role: '上门师傅', action: '接单上门 → 交付成功上传照片 / 失败填写原因' },
  ],
}

/** 裸宽、融合线上办理：不派师傅上门开户 */
export function skipTechDispatch(bizType: BizType) {
  return bizType === 'broadband_no_card' || bizType === 'broadband_naked'
}

export function opsFlowActive(bizType: BizType, status: OrderStatus): number {
  if (status === 'cancelled') return 0
  if (status === 'follow_up' || status === 'failed') return 2
  if (skipTechDispatch(bizType)) {
    const map: Partial<Record<OrderStatus, number>> = {
      listed: 1,
      merchant_accepted: 2,
      boss_opened: 2,
      installing: 3,
      done: 4,
    }
    return map[status] ?? 1
  }
  const map: Partial<Record<OrderStatus, number>> = {
    listed: 1,
    merchant_accepted: 2,
    dispatched: 2,
    tech_accepted: 3,
    boss_opened: bizType === 'haoka' ? 4 : 3,
    installing: 4,
    done: 5,
  }
  return map[status] ?? 1
}

export function cFlowActive(bizType: BizType, status: OrderStatus): number {
  if (status === 'cancelled') return -1
  if (status === 'follow_up' || status === 'failed') return 1
  if (skipTechDispatch(bizType)) {
    const map: Partial<Record<OrderStatus, number>> = {
      listed: 0,
      merchant_accepted: 1,
      boss_opened: 1,
      installing: 2,
      done: 3,
    }
    return map[status] ?? 0
  }
  const map: Partial<Record<OrderStatus, number>> = {
    listed: 0,
    merchant_accepted: 1,
    dispatched: 1,
    tech_accepted: 2,
    boss_opened: 2,
    installing: 3,
    done: 4,
  }
  return map[status] ?? 0
}
