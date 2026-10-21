/** 后台权限点（叶子节点，角色勾选后生效） */
export type Permission =
  | '*'
  | 'dashboard:view'
  | 'orders:view'
  | 'orders:edit'
  | 'products:view'
  | 'products:edit'
  | 'agents:view'
  | 'agents:edit'
  | 'warehouse:view'
  | 'warehouse:edit'
  | 'stock:view'
  | 'stock:in'
  | 'stock:out'
  | 'merchants:view'
  | 'merchants:edit'
  | 'technicians:view'
  | 'technicians:edit'
  | 'users:view'
  | 'users:edit'
  | 'service:view'
  | 'service:edit'
  | 'feedback:view'
  | 'feedback:edit'
  | 'content:view'
  | 'content:edit'
  | 'flows:view'
  | 'accounts:view'
  | 'accounts:edit'
  | 'roles:view'
  | 'roles:edit'

export interface PermNode {
  id: string
  label: string
  children?: PermNode[]
}

/** 角色权限树，管理员创建角色时勾选 */
export const PERMISSION_TREE: PermNode[] = [
  { id: 'g-dash', label: '运营', children: [{ id: 'dashboard:view', label: '查看概览' }] },
  {
    id: 'g-order',
    label: '订单',
    children: [
      { id: 'orders:view', label: '查看订单' },
      { id: 'orders:edit', label: '处理订单（备注 / 取消）' },
    ],
  },
  {
    id: 'g-product',
    label: '产品',
    children: [
      { id: 'products:view', label: '查看商品套餐 / 存量业务类型' },
      { id: 'products:edit', label: '编辑商品套餐 / 存量业务类型' },
    ],
  },
  {
    id: 'g-agent',
    label: 'App 代理',
    children: [
      { id: 'agents:view', label: '查看代理入驻申请 / 代理商' },
      { id: 'agents:edit', label: '审核代理入驻 / 编辑代理商' },
    ],
  },
  {
    id: 'g-wh',
    label: '产品仓库',
    children: [
      { id: 'warehouse:view', label: '查看库存' },
      { id: 'warehouse:edit', label: '维护仓库资料' },
    ],
  },
  {
    id: 'g-stock',
    label: '产品订单出入库',
    children: [
      { id: 'stock:view', label: '查看出入库记录' },
      { id: 'stock:in', label: '入库' },
      { id: 'stock:out', label: '出库（关联订单）' },
    ],
  },
  {
    id: 'g-mp',
    label: '小程序',
    children: [
      { id: 'merchants:view', label: '查看商家入驻申请 / 本地商家' },
      { id: 'merchants:edit', label: '审核商家入驻 / 编辑本地商家' },
      { id: 'technicians:view', label: '查看上门师傅' },
      { id: 'technicians:edit', label: '编辑上门师傅（一般由商家在小程序维护）' },
    ],
  },
  {
    id: 'g-app',
    label: 'App 配置',
    children: [
      { id: 'users:view', label: '查看 App 用户' },
      { id: 'users:edit', label: '停用 / 启用用户' },
      { id: 'service:view', label: '查看客服配置' },
      { id: 'service:edit', label: '编辑客服配置' },
      { id: 'feedback:view', label: '查看客服留言' },
      { id: 'feedback:edit', label: '处理客服留言' },
      { id: 'content:view', label: '查看协议与帮助' },
      { id: 'content:edit', label: '编辑协议与帮助' },
    ],
  },
  { id: 'g-flow', label: '业务流转', children: [{ id: 'flows:view', label: '查看业务流转' }] },
  {
    id: 'g-sys',
    label: '账号与权限',
    children: [
      { id: 'accounts:view', label: '查看后台账号' },
      { id: 'accounts:edit', label: '创建 / 删除账号' },
      { id: 'roles:view', label: '查看角色' },
      { id: 'roles:edit', label: '创建角色并配置权限' },
    ],
  },
]

export function leafPermissions(nodes: PermNode[] = PERMISSION_TREE): Permission[] {
  const out: Permission[] = []
  for (const n of nodes) {
    if (n.children?.length) out.push(...leafPermissions(n.children))
    else if (n.id.includes(':')) out.push(n.id as Permission)
  }
  return out
}

export const ALL_PERMISSIONS = leafPermissions()

export interface Role {
  id: string
  name: string
  code: string
  /** 系统预置不可删除 */
  builtin: boolean
  /** 含 * 表示全部权限 */
  permissions: Permission[]
  remark: string
}

export interface Staff {
  id: string
  username: string
  password: string
  name: string
  roleId: string
  status: 'active' | 'disabled'
  createdAt: string
}

export const FINANCE_PERMISSIONS: Permission[] = [
  'dashboard:view',
  'products:view',
  'agents:view',
  'orders:view',
  'warehouse:view',
]

export const SERVICE_PERMISSIONS: Permission[] = [
  'dashboard:view',
  'orders:view',
  'orders:edit',
  'warehouse:view',
  'stock:view',
  'stock:in',
  'stock:out',
  'service:view',
  'service:edit',
  'feedback:view',
  'feedback:edit',
  'content:view',
  'users:view',
]

export const mockRoles: Role[] = [
  {
    id: 'r-admin',
    name: '管理员',
    code: 'admin',
    builtin: true,
    permissions: ['*'],
    remark: '全部权限，含账号与角色管理',
  },
  {
    id: 'r-finance',
    name: '财务',
    code: 'finance',
    builtin: true,
    permissions: [...FINANCE_PERMISSIONS],
    remark: '查看套餐佣金、代理商、订单、产品仓库',
  },
  {
    id: 'r-service',
    name: '客服',
    code: 'service',
    builtin: true,
    permissions: [...SERVICE_PERMISSIONS],
    remark: '客服留言、FAQ 配置与订单协助',
  },
]

export const mockStaff: Staff[] = [
  { id: 's1', username: 'admin', password: '123456', name: '系统管理员', roleId: 'r-admin', status: 'active', createdAt: '2026-08-01 09:00:00' },
  { id: 's2', username: 'finance', password: '123456', name: '财务小王', roleId: 'r-finance', status: 'active', createdAt: '2026-08-10 09:00:00' },
  { id: 's3', username: 'service', password: '123456', name: '客服小李', roleId: 'r-service', status: 'active', createdAt: '2026-08-10 09:00:00' },
  { id: 's4', username: 'service2', password: '123456', name: '客服小周', roleId: 'r-service', status: 'active', createdAt: '2026-08-12 09:00:00' },
  { id: 's5', username: 'service3', password: '123456', name: '客服小陈', roleId: 'r-service', status: 'active', createdAt: '2026-08-13 09:00:00' },
  { id: 's6', username: 'finance2', password: '123456', name: '财务小赵', roleId: 'r-finance', status: 'active', createdAt: '2026-08-14 09:00:00' },
]
