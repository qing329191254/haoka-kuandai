import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { del, get, post, put } from '@/api/http'
import type { Agent, AgentApplication, DepositRule, StockRecord, StockType, WarehouseItem } from '@/types/stock'
import type {
  AppUser,
  ContentDoc,
  FaqItem,
  FeedbackItem,
  Merchant,
  MerchantApplication,
  Order,
  Product,
  AppVersionConfig,
  ServiceConfig,
  StockBizType,
  Technician,
} from '@/types/order'
import { useAuthStore } from '@/stores/auth'

function nowStr() {
  const d = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

export const useAdminStore = defineStore('admin', () => {
  const orders = ref<Order[]>([])
  const merchants = ref<Merchant[]>([])
  const merchantApplications = ref<MerchantApplication[]>([])
  const technicians = ref<Technician[]>([])
  const products = ref<Product[]>([])
  const stockBizTypes = ref<StockBizType[]>([])
  const appUsers = ref<AppUser[]>([])
  const faqs = ref<FaqItem[]>([])
  const feedbacks = ref<FeedbackItem[]>([])
  const docs = ref<ContentDoc[]>([])
  const serviceConfig = ref<ServiceConfig>({ hotline: '', workTime: '', quickReplies: [] })
  const appVersion = ref<AppVersionConfig>({
    latestVersion: '1.0.0',
    minSupportedVersion: '1.0.0',
    forceUpdate: false,
    title: '发现新版本',
    releaseNotes: '',
    androidUrl: '',
    iosUrl: '',
    enabled: true,
  })
  const agents = ref<Agent[]>([])
  const agentApplications = ref<AgentApplication[]>([])
  const depositRules = ref<DepositRule[]>([])
  const warehouse = ref<WarehouseItem[]>([])
  const stockRecords = ref<StockRecord[]>([])
  const dashboard = ref<Record<string, number>>({})

  const stats = computed(() => {
    const d = dashboard.value
    if (d && Object.keys(d).length) {
      return {
        total: d.total || 0,
        pending: d.pending || 0,
        processing: d.processing || 0,
        done: d.done || 0,
        cancelled: d.cancelled || 0,
        failed: d.followUp || 0,
        followUp: d.followUp || 0,
        haoka: d.haoka || 0,
        broadbandNew: 0,
        broadbandNo: 0,
        mpTodo: d.mpTodo || 0,
        merchantActive: d.merchantActive || 0,
        agentActive: d.agentActive || 0,
        warehouseSku: d.warehouseSku || 0,
        warehouseQty: d.warehouseQty || 0,
        stockLow: d.stockLow || 0,
        stockIn: d.stockIn || 0,
        stockOut: d.stockOut || 0,
      }
    }
    const all = orders.value
    return {
      total: all.length,
      pending: all.filter((o) => o.status === 'listed').length,
      processing: all.filter((o) => !['listed', 'done', 'cancelled', 'follow_up', 'failed'].includes(o.status)).length,
      done: all.filter((o) => o.status === 'done').length,
      cancelled: all.filter((o) => o.status === 'cancelled').length,
      failed: all.filter((o) => o.status === 'follow_up' || o.status === 'failed').length,
      followUp: all.filter((o) => o.status === 'follow_up' || o.status === 'failed').length,
      haoka: all.filter((o) => o.bizType === 'haoka').length,
      broadbandNew: all.filter((o) => o.bizType === 'broadband_new_card').length,
      broadbandNo: all.filter((o) => o.bizType === 'broadband_no_card').length,
      mpTodo: technicians.value.filter((t) => t.status === 'active').length,
      merchantActive: merchants.value.filter((m) => m.status === 'active').length,
      agentActive: agents.value.filter((a) => a.status === 'active').length,
      warehouseSku: warehouse.value.length,
      warehouseQty: warehouse.value.reduce((n, w) => n + w.stock, 0),
      stockLow: warehouse.value.filter((w) => w.stock <= w.safetyStock).length,
      stockIn: stockRecords.value.filter((r) => r.type === 'in').length,
      stockOut: stockRecords.value.filter((r) => r.type === 'out').length,
    }
  })

  async function hydrate() {
    const tasks: Promise<void>[] = []
    const take = async (url: string, assign: (items: never[]) => void) => {
      try {
        const res = await get<{ items?: never[] }>(url)
        assign(res.items || [])
      } catch {
        /* 无权限的模块跳过 */
      }
    }
    tasks.push(take('/api/admin/orders', (v) => (orders.value = v as Order[])))
    tasks.push(take('/api/admin/merchants', (v) => (merchants.value = v as Merchant[])))
    tasks.push(take('/api/admin/merchant-applications', (v) => (merchantApplications.value = v as MerchantApplication[])))
    tasks.push(take('/api/admin/technicians', (v) => (technicians.value = v as Technician[])))
    tasks.push(take('/api/admin/products', (v) => (products.value = v as Product[])))
    tasks.push(take('/api/admin/stock-types', (v) => (stockBizTypes.value = v as StockBizType[])))
    tasks.push(take('/api/admin/users', (v) => (appUsers.value = v as AppUser[])))
    tasks.push(take('/api/admin/faqs', (v) => (faqs.value = v as FaqItem[])))
    tasks.push(take('/api/admin/feedbacks', (v) => (feedbacks.value = v as FeedbackItem[])))
    tasks.push(take('/api/admin/docs', (v) => (docs.value = v as ContentDoc[])))
    tasks.push(take('/api/admin/agents', (v) => (agents.value = v as Agent[])))
    tasks.push(take('/api/admin/agent-applications', (v) => (agentApplications.value = v as AgentApplication[])))
    tasks.push(take('/api/admin/deposit-rules', (v) => (depositRules.value = v as DepositRule[])))
    tasks.push(take('/api/admin/warehouse', (v) => (warehouse.value = v as WarehouseItem[])))
    tasks.push(take('/api/admin/stock-records', (v) => (stockRecords.value = v as StockRecord[])))
    tasks.push(
      (async () => {
        try {
          dashboard.value = (await get('/api/admin/dashboard')) as Record<string, number>
        } catch {
          dashboard.value = {}
        }
      })(),
    )
    tasks.push(
      (async () => {
        try {
          serviceConfig.value = await get('/api/admin/service-config')
        } catch {
          /* ignore */
        }
      })(),
    )
    tasks.push(
      (async () => {
        try {
          appVersion.value = await get('/api/admin/app-version')
        } catch {
          /* ignore */
        }
      })(),
    )
    await Promise.all(tasks)
    const auth = useAuthStore()
    await auth.loadStaff()
  }

  function getOrder(id: string) {
    return orders.value.find((o) => o.id === id)
  }

  async function fetchOrder(id: string) {
    try {
      const row = await get<Order>(`/api/admin/orders/${id}`)
      const i = orders.value.findIndex((o) => o.id === row.id)
      if (i >= 0) orders.value[i] = row
      else orders.value.unshift(row)
      return row
    } catch {
      return getOrder(id)
    }
  }

  async function cancelOrder(id: string, remark: string) {
    await post(`/api/admin/orders/${id}/cancel`, { remark, reason: remark })
    await hydrate()
    return true
  }

  async function remarkOrder(id: string, remark: string) {
    await post(`/api/admin/orders/${id}/remark`, { remark })
    await hydrate()
    return true
  }

  async function upsertMerchant(row: Merchant) {
    const body = { ...row, loginPhone: row.phone }
    if (merchants.value.some((m) => m.id === row.id)) await put(`/api/admin/merchants/${row.id}`, body)
    else await post('/api/admin/merchants', body)
    await hydrate()
  }

  async function removeMerchant(id: string) {
    await del(`/api/admin/merchants/${id}`)
    await hydrate()
  }

  function toggleEnable<T extends { status: string }>(list: T[], index: number) {
    const item = list[index]
    if (!item) return
    item.status = item.status === 'active' ? 'disabled' : 'active'
  }

  async function toggleById<T extends { id: string; status: string }>(list: T[], id: string) {
    const item = list.find((x) => x.id === id)
    if (!item) return
    const prev = item.status
    item.status = item.status === 'active' ? 'disabled' : 'active'
    try {
      if (list === merchants.value) await upsertMerchant(item as unknown as Merchant)
      else if (list === products.value) await upsertProduct(item as unknown as Product)
      else if (list === agents.value) await upsertAgent(item as unknown as Agent)
      else if (list === stockBizTypes.value) await upsertStockBizType(item as unknown as StockBizType)
      else if (list === technicians.value) await upsertTechnician(item as unknown as Technician)
    } catch (e) {
      item.status = prev
      ElMessage.error(e instanceof Error ? e.message : '状态更新失败')
    }
  }

  async function upsertTechnician(row: Technician) {
    if (technicians.value.some((t) => t.id === row.id)) await put(`/api/admin/technicians/${row.id}`, row)
    else await post('/api/admin/technicians', row)
    await hydrate()
  }

  async function removeTechnician(id: string) {
    await del(`/api/admin/technicians/${id}`)
    await hydrate()
  }

  async function upsertProduct(row: Product) {
    const exists = products.value.some((p) => p.id === row.id)
    if (exists) await put(`/api/admin/products/${row.id}`, row)
    else await post('/api/admin/products', row)
    await hydrate()
  }

  async function upsertStockBizType(row: StockBizType) {
    const exists = stockBizTypes.value.some((t) => t.id === row.id)
    if (exists) await put(`/api/admin/stock-types/${row.id}`, row)
    else await post('/api/admin/stock-types', row)
    await hydrate()
  }

  async function removeStockBizType(id: string) {
    if (products.value.some((p) => p.stockTypeId === id)) return '该类型下仍有套餐，请先调整或下架后再删除'
    try {
      await del(`/api/admin/stock-types/${id}`)
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '删除失败'
    }
  }

  async function upsertDepositRule(row: DepositRule) {
    const exists = depositRules.value.some((r) => r.id === row.id)
    if (exists) await put(`/api/admin/deposit-rules/${row.id}`, row)
    else await post('/api/admin/deposit-rules', row)
    await hydrate()
  }

  async function removeDepositRule(id: string) {
    try {
      await del(`/api/admin/deposit-rules/${id}`)
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '删除失败'
    }
  }

  async function toggleUser(id: string) {
    try {
      await post(`/api/admin/users/${id}/toggle`)
      await hydrate()
    } catch (e) {
      ElMessage.error(e instanceof Error ? e.message : '操作失败')
    }
  }

  async function upsertFaq(row: FaqItem) {
    const exists = faqs.value.some((f) => f.id === row.id)
    if (exists) await put(`/api/admin/faqs/${row.id}`, row)
    else await post('/api/admin/faqs', row)
    await hydrate()
  }

  async function removeFaq(id: string) {
    await del(`/api/admin/faqs/${id}`)
    await hydrate()
  }

  async function handleFeedback(id: string, body?: { reply?: string; note?: string }) {
    await post(`/api/admin/feedbacks/${id}/handle`, body || {})
    await hydrate()
  }

  async function reopenFeedback(id: string) {
    await post(`/api/admin/feedbacks/${id}/reopen`)
    await hydrate()
  }

  async function saveDoc(row: ContentDoc) {
    await put(`/api/admin/docs/${row.id}`, row)
    await hydrate()
  }

  async function saveServiceConfig(cfg: ServiceConfig) {
    await put('/api/admin/service-config', cfg)
    await hydrate()
  }

  async function saveAppVersion(cfg: AppVersionConfig) {
    await put('/api/admin/app-version', cfg)
    await hydrate()
  }

  async function upsertAgent(row: Agent) {
    if (agents.value.some((a) => a.id === row.id)) await put(`/api/admin/agents/${row.id}`, row)
    else await post('/api/admin/agents', row)
    await hydrate()
  }

  async function removeAgent(id: string) {
    await del(`/api/admin/agents/${id}`)
    await hydrate()
  }

  async function approveApplication(id: string) {
    try {
      await post(`/api/admin/agent-applications/${id}/approve`)
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '审核失败'
    }
  }

  async function rejectApplication(id: string, reason: string) {
    try {
      await post(`/api/admin/agent-applications/${id}/reject`, { reason })
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '操作失败'
    }
  }

  async function approveMerchantApplication(id: string) {
    try {
      await post(`/api/admin/merchant-applications/${id}/approve`)
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '审核失败'
    }
  }

  async function rejectMerchantApplication(id: string, reason: string) {
    try {
      await post(`/api/admin/merchant-applications/${id}/reject`, { reason })
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '操作失败'
    }
  }

  async function upsertWarehouse(row: WarehouseItem) {
    if (warehouse.value.some((w) => w.id === row.id)) await put(`/api/admin/warehouse/${row.id}`, row)
    else await post('/api/admin/warehouse', row)
    await hydrate()
  }

  async function addStock(payload: {
    type: StockType
    warehouseId: string
    qty: number
    orderNo?: string
    operator: string
    remark?: string
  }) {
    try {
      await post(`/api/admin/stock/${payload.type}`, {
        warehouseId: payload.warehouseId,
        qty: payload.qty,
        orderNo: payload.orderNo,
        remark: payload.remark,
      })
      await hydrate()
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '出入库失败'
    }
  }

  return {
    orders,
    merchants,
    merchantApplications,
    technicians,
    products,
    stockBizTypes,
    appUsers,
    faqs,
    feedbacks,
    docs,
    serviceConfig,
    appVersion,
    agents,
    agentApplications,
    depositRules,
    warehouse,
    stockRecords,
    stats,
    hydrate,
    getOrder,
    fetchOrder,
    cancelOrder,
    remarkOrder,
    upsertMerchant,
    removeMerchant,
    upsertTechnician,
    removeTechnician,
    upsertProduct,
    upsertStockBizType,
    removeStockBizType,
    upsertDepositRule,
    removeDepositRule,
    toggleEnable,
    toggleById,
    toggleUser,
    upsertFaq,
    removeFaq,
    handleFeedback,
    reopenFeedback,
    saveDoc,
    saveServiceConfig,
    saveAppVersion,
    upsertAgent,
    removeAgent,
    approveApplication,
    rejectApplication,
    approveMerchantApplication,
    rejectMerchantApplication,
    upsertWarehouse,
    addStock,
  }
})
