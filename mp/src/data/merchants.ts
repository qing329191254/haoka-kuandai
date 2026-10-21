/** 商家入驻审核状态 */
export type MerchantAuditStatus = 'pending' | 'approved' | 'rejected'

export type BizTypeKey =
  | 'haoka'
  | 'contract_phone'
  | 'broadband_naked'
  | 'broadband_new_card'
  | 'broadband_no_card'
  | 'wifi'
  | 'cpe'
  | 'stock'

export interface LocalMerchant {
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
  bizTypes: BizTypeKey[]
  status: MerchantAuditStatus
  rejectReason?: string
  /** 小程序展示名 */
  mpDisplayName: string
}

const KEY = 'haoka_mp_merchants_v2'

/** 演示：已通过审核的门店（可登录接单） */
const SEED_APPROVED: LocalMerchant[] = [
  {
    id: 'm1',
    name: '西湖号卡店',
    phone: '13800001001',
    contact: '陈经理',
    province: '浙江省',
    city: '杭州市',
    district: '西湖区',
    address: '文三路100号',
    wechat: 'xh_hk',
    backupPhone: '0571-88880001',
    idNo: '330106199001011111',
    licenseName: 'license_m1.jpg',
    remark: '',
    bizTypes: ['haoka', 'contract_phone', 'broadband_naked', 'broadband_new_card', 'wifi', 'cpe', 'stock'],
    status: 'approved',
    mpDisplayName: '西湖号卡店',
  },
  {
    id: 'm2',
    name: '滨江宽带专营',
    phone: '13800001002',
    contact: '周经理',
    province: '浙江省',
    city: '杭州市',
    district: '滨江区',
    address: '网商路999号',
    wechat: '',
    backupPhone: '0571-88880002',
    idNo: '330108199002021111',
    licenseName: 'license_m2.jpg',
    remark: '',
    bizTypes: ['contract_phone', 'broadband_naked', 'broadband_new_card', 'broadband_no_card', 'wifi', 'cpe'],
    status: 'approved',
    mpDisplayName: '滨江宽带专营',
  },
  {
    id: 'm3',
    name: '余杭本地商家',
    phone: '13800001003',
    contact: '吴经理',
    province: '浙江省',
    city: '杭州市',
    district: '余杭区',
    address: '文一西路88号',
    wechat: '',
    backupPhone: '',
    idNo: '330110199003031111',
    licenseName: 'license_m3.jpg',
    remark: '',
    bizTypes: ['haoka', 'contract_phone', 'broadband_naked', 'broadband_new_card', 'broadband_no_card'],
    status: 'approved',
    mpDisplayName: '余杭本地商家',
  },
]

/** 演示：待审核 / 已驳回 */
const SEED_OTHER: LocalMerchant[] = [
  {
    id: 'm_pending',
    name: '拱墅新申请门店',
    phone: '13800009901',
    contact: '刘经理',
    province: '浙江省',
    city: '杭州市',
    district: '拱墅区',
    address: '莫干山路66号',
    wechat: 'gs_apply',
    backupPhone: '',
    idNo: '330105199104041111',
    licenseName: 'apply_gs.jpg',
    remark: '希望承接号卡与宽带',
    bizTypes: ['haoka', 'broadband_new_card'],
    status: 'pending',
    mpDisplayName: '拱墅新申请门店',
  },
  {
    id: 'm_rejected',
    name: '证件不全门店',
    phone: '13800009902',
    contact: '何某',
    province: '浙江省',
    city: '杭州市',
    district: '上城区',
    address: '延安路1号',
    wechat: '',
    backupPhone: '',
    idNo: '',
    licenseName: '',
    remark: '',
    bizTypes: ['haoka'],
    status: 'rejected',
    rejectReason: '证件照片不清晰，请重新上传后再次申请',
    mpDisplayName: '证件不全门店',
  },
]

function loadAll(): LocalMerchant[] {
  try {
    const raw = uni.getStorageSync(KEY)
    if (raw) {
      const list = typeof raw === 'string' ? JSON.parse(raw) : raw
      if (Array.isArray(list) && list.length) return list as LocalMerchant[]
    }
  } catch {
    /* ignore */
  }
  const seed = [...SEED_APPROVED, ...SEED_OTHER]
  uni.setStorageSync(KEY, seed)
  return seed
}

function saveAll(list: LocalMerchant[]) {
  uni.setStorageSync(KEY, list)
}

export function listMerchants(): LocalMerchant[] {
  return loadAll()
}

export function merchantById(id?: string | null) {
  if (!id) return undefined
  return loadAll().find((m) => m.id === id)
}

export function merchantByPhone(phone: string) {
  const p = phone.trim()
  return loadAll().find((m) => m.phone === p)
}

export function listApprovedMerchants() {
  return loadAll().filter((m) => m.status === 'approved')
}

/** 兼容旧引用 */
export const LOCAL_MERCHANTS = SEED_APPROVED.map((m) => ({
  id: m.id,
  name: m.name,
  province: m.province,
  city: m.city,
  district: m.district,
}))

export function submitMerchantApply(input: Omit<LocalMerchant, 'id' | 'status' | 'mpDisplayName'> & { mpDisplayName?: string }) {
  const list = loadAll()
  const exist = list.find((m) => m.phone === input.phone.trim())
  if (exist?.status === 'approved') return '该手机号已通过审核，请直接登录'
  if (exist?.status === 'pending') return '该手机号已有待审核申请'

  const row: LocalMerchant = {
    ...input,
    phone: input.phone.trim(),
    id: exist?.id || `m${Date.now()}`,
    status: 'pending',
    mpDisplayName: input.mpDisplayName || input.name,
    rejectReason: undefined,
  }
  if (exist) {
    const i = list.findIndex((m) => m.id === exist.id)
    list[i] = row
  } else {
    list.unshift(row)
  }
  saveAll(list)
  return ''
}

/** 演示用：本地更新状态（正式由后台接口回写） */
export function setMerchantAuditStatus(phone: string, status: MerchantAuditStatus, rejectReason = '') {
  const list = loadAll()
  const i = list.findIndex((m) => m.phone === phone.trim())
  if (i < 0) return
  list[i] = { ...list[i], status, rejectReason: status === 'rejected' ? rejectReason : undefined }
  saveAll(list)
}

/** 演示区域选项（全国级联正式接接口） */
export const REGION_OPTIONS: Array<{ province: string; city: string; districts: string[] }> = [
  {
    province: '浙江省',
    city: '杭州市',
    districts: ['西湖区', '滨江区', '余杭区', '萧山区', '拱墅区', '上城区', '临平区', '钱塘区'],
  },
  {
    province: '江苏省',
    city: '南京市',
    districts: ['鼓楼区', '玄武区', '江宁区', '秦淮区', '建邺区'],
  },
  {
    province: '江苏省',
    city: '苏州市',
    districts: ['姑苏区', '工业园区', '虎丘区'],
  },
  {
    province: '广东省',
    city: '广州市',
    districts: ['天河区', '越秀区', '海珠区'],
  },
  {
    province: '广东省',
    city: '深圳市',
    districts: ['南山区', '福田区', '宝安区'],
  },
]
