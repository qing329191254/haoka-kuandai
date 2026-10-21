import type { Role } from '@/types/order'
import { clearToken, request, setToken } from '@/api/http'
import { showToast } from '@/store/feedback'

const KEY = 'haoka_mp_session'

export interface MpSession {
  role: Role
  displayName: string
  phone: string
  merchantId?: string
  auditStatus?: 'pending' | 'approved' | 'rejected'
  rejectReason?: string
  loggedAt: string
}

export function getSession(): MpSession | null {
  try {
    const raw = uni.getStorageSync(KEY)
    if (!raw) return null
    const s = typeof raw === 'string' ? JSON.parse(raw) : raw
    if ((s?.role === 'merchant' || s?.role === 'technician') && s?.phone) {
      return s as MpSession
    }
    return null
  } catch {
    return null
  }
}

function persist(session: MpSession) {
  uni.setStorageSync(KEY, session)
  return session
}

export async function loginByPhone(phone: string, expectedRole?: Role, code = '123456'): Promise<string | null> {
  const p = phone.trim()
  if (!/^1\d{10}$/.test(p)) return '请输入正确的 11 位手机号'
  const role = expectedRole || 'merchant'
  try {
    const data = await request<{
      token: string
      session: {
        role: Role
        displayName: string
        phone: string
        merchantId?: string
        auditStatus?: MpSession['auditStatus']
        rejectReason?: string
      }
    }>({
      url: '/api/mp/auth/login',
      method: 'POST',
      data: { phone: p, code, role },
    })
    setToken(data.token)
    persist({
      role: data.session.role,
      displayName: data.session.displayName,
      phone: data.session.phone,
      merchantId: data.session.merchantId,
      auditStatus: data.session.auditStatus,
      rejectReason: data.session.rejectReason,
      loggedAt: new Date().toISOString(),
    })
    return null
  } catch (e) {
    return e instanceof Error ? e.message : '登录失败'
  }
}

export function clearSession() {
  uni.removeStorageSync(KEY)
  clearToken()
}

export function requireRole(role: Role): MpSession | null {
  const s = getSession()
  if (!s || s.role !== role) {
    showToast('请先用对应账号登录', { type: 'error' })
    setTimeout(() => {
      uni.reLaunch({ url: '/pages/index/index' })
    }, 400)
    return null
  }
  if (role === 'merchant' && (!s.merchantId || s.auditStatus !== 'approved')) {
    uni.reLaunch({ url: '/pages/merchant/audit' })
    return null
  }
  return s
}

export function goRoleHome(role: Role) {
  if (role === 'merchant') {
    const s = getSession()
    if (s?.auditStatus && s.auditStatus !== 'approved') {
      uni.reLaunch({ url: '/pages/merchant/audit' })
      return
    }
    uni.reLaunch({ url: '/pages/merchant/home' })
  } else {
    uni.reLaunch({ url: '/pages/tech/home' })
  }
}

export function logout() {
  clearSession()
  uni.reLaunch({ url: '/pages/index/index' })
}

export function switchRole() {
  logout()
}

export async function refreshMerchantSession() {
  const s = getSession()
  if (!s) return s
  try {
    const me = await request<{
      role: Role
      displayName: string
      phone: string
      merchantId?: string
      auditStatus?: MpSession['auditStatus']
      rejectReason?: string
      province?: string
      city?: string
      district?: string
    }>({ url: '/api/mp/me' })
    return persist({
      ...s,
      displayName: me.displayName || s.displayName,
      merchantId: me.merchantId,
      auditStatus: me.auditStatus,
      rejectReason: me.rejectReason,
    })
  } catch {
    return s
  }
}
