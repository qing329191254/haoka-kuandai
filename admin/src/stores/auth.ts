import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { clearToken, del, get, post, put, setToken } from '@/api/http'
import type { Permission, Role, Staff } from '@/types/auth'

const SESSION_KEY = 'admin_session'

type SessionUser = Staff & { roleName?: string }

export const useAuthStore = defineStore('auth', () => {
  const roles = ref<Role[]>([])
  const staff = ref<Staff[]>([])
  const current = ref<SessionUser | null>(null)
  const permissions = ref<string[]>([])
  let sessionChecked = false

  function persist() {
    if (!current.value) {
      localStorage.removeItem(SESSION_KEY)
      return
    }
    localStorage.setItem(
      SESSION_KEY,
      JSON.stringify({ user: current.value, permissions: permissions.value, roles: roles.value }),
    )
  }

  function restore() {
    const raw = localStorage.getItem(SESSION_KEY)
    if (!raw) {
      current.value = null
      return
    }
    try {
      const parsed = JSON.parse(raw) as { user: SessionUser; permissions?: string[]; roles?: Role[] }
      current.value = parsed.user
      permissions.value = parsed.permissions || []
      if (parsed.roles?.length) roles.value = parsed.roles
    } catch {
      current.value = null
    }
  }

  restore()

  const role = computed(() => roles.value.find((r) => r.id === current.value?.roleId) || null)

  function hasPermission(perm: Permission | string) {
    if (!current.value) return false
    if (permissions.value.includes('*')) return true
    if (role.value?.permissions.includes('*')) return true
    return permissions.value.includes(perm) || !!role.value?.permissions.includes(perm as Permission)
  }

  function canAny(...perms: string[]) {
    return perms.some((p) => hasPermission(p))
  }

  async function login(username: string, password: string) {
    try {
      const data = await post<{
        token: string
        user: { id: string; username: string; name: string; roleId: string; roleName: string; permissions: string[] }
      }>('/api/admin/auth/login', { username, password })
      setToken(data.token)
      current.value = {
        id: data.user.id,
        username: data.user.username,
        password: '',
        name: data.user.name,
        roleId: data.user.roleId,
        status: 'active',
        createdAt: '',
        roleName: data.user.roleName,
      }
      permissions.value = data.user.permissions || []
      roles.value = [
        {
          id: data.user.roleId,
          name: data.user.roleName,
          code: data.user.roleId,
          builtin: true,
          permissions: data.user.permissions as Permission[],
          remark: '',
        },
      ]
      persist()
      sessionChecked = true
      try {
        const extra = await get<{ items: Role[] }>('/api/admin/roles')
        if (extra.items?.length) roles.value = extra.items
        persist()
      } catch {
        /* 财务等角色可能无角色管理权限 */
      }
      return { ok: true, message: '登录成功' }
    } catch (e) {
      return { ok: false, message: e instanceof Error ? e.message : '登录失败' }
    }
  }

  function logout() {
    current.value = null
    permissions.value = []
    sessionChecked = false
    clearToken()
    localStorage.removeItem(SESSION_KEY)
  }

  function firstAllowedPath() {
    const map: [string, string][] = [
      ['dashboard:view', '/dashboard'],
      ['orders:view', '/orders'],
      ['products:view', '/products'],
      ['agents:view', '/agent-apps'],
      ['merchants:view', '/merchants'],
      ['technicians:view', '/technicians'],
      ['users:view', '/users'],
      ['service:view', '/service'],
      ['content:view', '/content'],
      ['warehouse:view', '/warehouse'],
      ['stock:view', '/stock'],
      ['accounts:view', '/accounts'],
      ['roles:view', '/roles'],
      ['flows:view', '/flows'],
      ['feedback:view', '/feedback'],
    ]
    for (const [perm, path] of map) {
      if (hasPermission(perm)) return path
    }
    return '/403'
  }

  async function restoreSession() {
    if (sessionChecked) return !!current.value
    restore()
    const token = localStorage.getItem('admin_token')
    if (!token) {
      sessionChecked = true
      current.value = null
      return false
    }
    try {
      const me = await get<{
        id: string
        username: string
        name: string
        roleId: string
        roleName: string
        permissions: string[]
      }>('/api/admin/me')
      current.value = {
        id: me.id,
        username: me.username,
        password: '',
        name: me.name,
        roleId: me.roleId,
        status: 'active',
        createdAt: '',
        roleName: me.roleName,
      }
      permissions.value = me.permissions || []
      persist()
      sessionChecked = true
      return true
    } catch {
      logout()
      sessionChecked = true
      return false
    }
  }

  async function loadStaff() {
    try {
      const [s, r] = await Promise.all([
        get<{ items: Staff[] }>('/api/admin/staff'),
        get<{ items: Role[] }>('/api/admin/roles'),
      ])
      staff.value = (s.items || []).map((x) => ({ ...x, password: '' }))
      if (r.items?.length) roles.value = r.items
    } catch {
      /* ignore */
    }
  }

  async function upsertRole(row: Role) {
    const body = {
      name: row.name,
      code: row.code,
      permissions: row.permissions,
      remark: row.remark,
    }
    if (roles.value.some((r) => r.id === row.id)) await put(`/api/admin/roles/${row.id}`, body)
    else await post('/api/admin/roles', body)
    await loadStaff()
    return ''
  }

  async function removeRole(id: string) {
    try {
      await del(`/api/admin/roles/${id}`)
      await loadStaff()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '删除失败'
    }
  }

  async function upsertStaff(row: Staff) {
    try {
      const body = {
        username: row.username,
        password: row.password || (row.id ? '' : '123456'),
        name: row.name,
        roleId: row.roleId,
        status: row.status || 'active',
      }
      if (staff.value.some((s) => s.id === row.id)) await put(`/api/admin/staff/${row.id}`, body)
      else await post('/api/admin/staff', body)
      await loadStaff()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '保存失败'
    }
  }

  async function removeStaff(id: string) {
    try {
      await del(`/api/admin/staff/${id}`)
      await loadStaff()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '删除失败'
    }
  }

  return {
    roles,
    staff,
    current,
    role,
    hasPermission,
    canAny,
    login,
    logout,
    restore,
    restoreSession,
    firstAllowedPath,
    upsertRole,
    removeRole,
    upsertStaff,
    removeStaff,
    loadStaff,
  }
})
