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
