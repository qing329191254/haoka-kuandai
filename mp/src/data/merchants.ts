/** 商家可接业务类型（与后台枚举一致） */
export type BizTypeKey =
  | 'haoka'
  | 'contract_phone'
  | 'broadband_naked'
  | 'broadband_new_card'
  | 'broadband_no_card'
  | 'wifi'
  | 'cpe'
  | 'stock'

export type MerchantAuditStatus = 'pending' | 'approved' | 'rejected'
