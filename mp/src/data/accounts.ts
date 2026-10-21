import type { Role } from '@/types/order'
import { listAllTechniciansByMerchant, findTechnicianByPhone, techBelongMerchantName } from '@/data/technicians'
import { listApprovedMerchants, listMerchants, merchantByPhone, type LocalMerchant } from '@/data/merchants'

/** 演示账号：手机号即身份凭证 */
export interface MpAccount {
  phone: string
  role: Role
  displayName: string
  merchantId?: string
  belongMerchantName?: string
  auditStatus?: LocalMerchant['status']
  rejectReason?: string
}

export function findAccountByPhone(phone: string): MpAccount | undefined {
  const p = phone.trim()
  const m = merchantByPhone(p)
  if (m) {
    return {
      phone: m.phone,
      role: 'merchant',
      displayName: m.mpDisplayName || m.name,
      merchantId: m.id,
      auditStatus: m.status,
      rejectReason: m.rejectReason,
    }
  }
  const t = findTechnicianByPhone(p)
  if (t) {
    return {
      phone: t.phone,
      role: 'technician',
      displayName: t.name,
      belongMerchantName: techBelongMerchantName(p),
    }
  }
  return undefined
}

export function defaultPhoneForRole(role: Role): string {
  if (role === 'merchant') {
    return listApprovedMerchants()[0]?.phone || '13800001001'
  }
  const first = listMerchants()[0]
  const tech = first ? listAllTechniciansByMerchant(first.id)[0] : undefined
  return tech?.phone || '13600001111'
}

export function demoQuickAccounts(): MpAccount[] {
  return [
    findAccountByPhone('13800001001'),
    findAccountByPhone('13800001002'),
    findAccountByPhone('13600001111'),
  ].filter((a): a is MpAccount => !!a)
}
