import { merchantById } from '@/data/merchants'

export type TechSkill = 'haoka' | 'contract_phone' | 'broadband_new_card' | 'wifi' | 'cpe' | 'stock'

export const TECH_SKILL_LABEL: Record<TechSkill, string> = {
  haoka: '号卡',
  contract_phone: '合约机',
  broadband_new_card: '融合宽带（新开卡）',
  wifi: 'WIFI 设备',
  cpe: 'CPE',
  stock: '存量',
}

export interface MpTechnician {
  id: string
  merchantId: string
  name: string
  phone: string
  province: string
  city: string
  district: string
  skills: TechSkill[]
  status: 'active' | 'disabled'
}

const KEY = 'haoka_mp_technicians_v3'

const surnames = ['李', '赵', '钱', '孙', '周', '吴', '郑', '王', '冯', '陈', '褚', '卫', '蒋', '沈', '韩', '杨']
const districts = ['西湖区', '上城区', '拱墅区', '余杭区']

const SEED: MpTechnician[] = [
  {
    id: 't1',
    merchantId: 'm1',
    name: '李师傅',
    phone: '13600001111',
    province: '浙江省',
    city: '杭州市',
    district: '西湖区',
    skills: ['haoka', 'contract_phone', 'broadband_new_card', 'wifi', 'cpe', 'stock'],
    status: 'active',
  },
  {
    id: 't2',
    merchantId: 'm2',
    name: '赵师傅',
    phone: '13600002222',
    province: '浙江省',
    city: '杭州市',
    district: '滨江区',
    skills: ['haoka', 'contract_phone', 'broadband_new_card', 'wifi', 'cpe'],
    status: 'active',
  },
  {
    id: 't3',
    merchantId: 'm3',
    name: '钱师傅',
    phone: '13600003333',
    province: '浙江省',
    city: '杭州市',
    district: '余杭区',
    skills: ['haoka'],
    status: 'active',
  },
  // 西湖店大批量师傅，验证列表按需加载
  ...Array.from({ length: 40 }, (_, i) => ({
    id: `t-m1-${i}`,
    merchantId: 'm1',
    name: `${surnames[i % surnames.length]}师傅${i + 1}`,
    phone: `1360101${String(1000 + i).slice(-4)}`,
    province: '浙江省',
    city: '杭州市',
    district: districts[i % districts.length],
    skills: (i % 3 === 0 ? ['haoka'] : ['haoka', 'broadband_new_card']) as TechSkill[],
    status: (i % 7 === 0 ? 'disabled' : 'active') as 'active' | 'disabled',
  })),
]

function loadAll(): MpTechnician[] {
  try {
    const raw = uni.getStorageSync(KEY)
    if (raw) {
      const list = typeof raw === 'string' ? JSON.parse(raw) : raw
      if (Array.isArray(list) && list.length) return list as MpTechnician[]
    }
  } catch {
    /* ignore */
  }
  uni.setStorageSync(KEY, SEED)
  return [...SEED]
}

function saveAll(list: MpTechnician[]) {
  uni.setStorageSync(KEY, list)
}

export function listTechniciansByMerchant(merchantId?: string) {
  if (!merchantId) return []
  return loadAll().filter((t) => t.merchantId === merchantId && t.status === 'active')
}

export function listAllTechniciansByMerchant(merchantId?: string) {
  if (!merchantId) return []
  return loadAll().filter((t) => t.merchantId === merchantId)
}

export function getTechnician(id: string) {
  return loadAll().find((t) => t.id === id)
}

export function findTechnicianByPhone(phone: string) {
  return loadAll().find((t) => t.phone === phone.trim())
}

export function upsertTechnician(row: Omit<MpTechnician, 'id'> & { id?: string }) {
  const list = loadAll()
  const phone = row.phone.trim()
  if (!/^1\d{10}$/.test(phone)) return '请输入正确手机号'
  if (!row.name.trim()) return '请填写姓名'
  const dup = list.find((t) => t.phone === phone && t.id !== row.id)
  if (dup) return '该手机号已被其他师傅使用'

  if (row.id) {
    const i = list.findIndex((t) => t.id === row.id)
    if (i < 0) return '师傅不存在'
    list[i] = { ...list[i], ...row, phone, name: row.name.trim() }
  } else {
    list.unshift({
      ...row,
      id: `t${Date.now()}`,
      phone,
      name: row.name.trim(),
    })
  }
  saveAll(list)
  return ''
}

export function removeTechnician(id: string) {
  saveAll(loadAll().filter((t) => t.id !== id))
}

export function techBelongMerchantName(phone: string) {
  const t = findTechnicianByPhone(phone)
  if (!t) return ''
  return merchantById(t.merchantId)?.name || ''
}
