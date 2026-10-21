import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/Login.vue'),
      meta: { public: true },
    },
    {
      path: '/',
      component: () => import('@/layouts/AdminLayout.vue'),
      redirect: '/dashboard',
      children: [
        { path: 'dashboard', name: 'dashboard', component: () => import('@/views/Dashboard.vue'), meta: { title: '运营概览', permission: 'dashboard:view' } },
        { path: 'orders', name: 'orders', component: () => import('@/views/orders/OrderList.vue'), meta: { title: '订单中心', permission: 'orders:view' } },
        { path: 'orders/:id', name: 'order-detail', component: () => import('@/views/orders/OrderDetail.vue'), meta: { title: '订单详情', permission: 'orders:view' } },
        { path: 'products', name: 'products', component: () => import('@/views/products/ProductList.vue'), meta: { title: '商品套餐', permission: 'products:view' } },
        { path: 'stock-types', name: 'stock-types', component: () => import('@/views/products/StockTypeList.vue'), meta: { title: '存量业务类型', permission: 'products:view' } },
        { path: 'agent-apps', name: 'agent-apps', component: () => import('@/views/agents/AgentApplyList.vue'), meta: { title: '代理入驻申请', permission: 'agents:view' } },
        { path: 'deposit-rules', name: 'deposit-rules', component: () => import('@/views/agents/DepositRuleList.vue'), meta: { title: '押金规则', permission: 'agents:view' } },
        { path: 'agents', name: 'agents', component: () => import('@/views/agents/AgentList.vue'), meta: { title: '代理商', permission: 'agents:view' } },
        { path: 'warehouse', name: 'warehouse', component: () => import('@/views/warehouse/WarehouseList.vue'), meta: { title: '号卡仓库', permission: 'warehouse:view' } },
        { path: 'stock', name: 'stock', component: () => import('@/views/warehouse/StockIO.vue'), meta: { title: '号卡出入库', permission: 'stock:view' } },
        { path: 'users', name: 'users', component: () => import('@/views/users/AppUserList.vue'), meta: { title: 'App 用户', permission: 'users:view' } },
        { path: 'service', name: 'service', component: () => import('@/views/service/FaqList.vue'), meta: { title: '客服配置', permission: 'service:view' } },
        { path: 'feedback', name: 'feedback', component: () => import('@/views/service/FeedbackList.vue'), meta: { title: '客服留言', permission: 'feedback:view' } },
        { path: 'content', name: 'content', component: () => import('@/views/content/DocList.vue'), meta: { title: '协议与帮助', permission: 'content:view' } },
        { path: 'merchants', name: 'merchants', component: () => import('@/views/merchants/MerchantList.vue'), meta: { title: '本地商家', permission: 'merchants:view' } },
        { path: 'merchant-apps', name: 'merchant-apps', component: () => import('@/views/merchants/MerchantApplyList.vue'), meta: { title: '商家入驻申请', permission: 'merchants:view' } },
        { path: 'technicians', name: 'technicians', component: () => import('@/views/technicians/TechList.vue'), meta: { title: '上门师傅', permission: 'technicians:view' } },
        { path: 'flows', name: 'flows', component: () => import('@/views/FlowGuide.vue'), meta: { title: '业务流转', permission: 'flows:view' } },
        { path: 'accounts', name: 'accounts', component: () => import('@/views/system/AccountList.vue'), meta: { title: '后台账号', permission: 'accounts:view' } },
        { path: 'roles', name: 'roles', component: () => import('@/views/system/RoleList.vue'), meta: { title: '角色权限', permission: 'roles:view' } },
        { path: '403', name: 'forbidden', component: () => import('@/views/Forbidden.vue'), meta: { title: '无权限' } },
      ],
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (to.meta.public) {
    if (to.path === '/login') {
      const ok = await auth.restoreSession()
      if (ok && auth.current) return auth.firstAllowedPath()
    }
    return true
  }
  const ok = await auth.restoreSession()
  if (!ok || !auth.current) return '/login'
  const perm = to.meta.permission
  if (perm && !auth.hasPermission(perm)) return '/403'
  return true
})

export default router
