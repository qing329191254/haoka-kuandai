<template>
  <div>
    <el-row :gutter="16">
      <el-col :span="6" v-for="item in cards" :key="item.label">
        <el-card shadow="never" class="stat-card" :style="{ '--accent': item.color }">
          <div class="stat">
            <div class="meta">
              <div class="label">{{ item.label }}</div>
              <div class="value">{{ item.value }}</div>
              <div class="desc">{{ item.desc }}</div>
            </div>
            <div class="icon" :style="{ background: item.tint }">
              <el-icon :size="20"><component :is="item.icon" /></el-icon>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <StatBoard v-if="can('orders:view') || can('warehouse:view')" />

    <el-row v-if="can('orders:view') || can('flows:view')" :gutter="16" style="margin-top: 16px">
      <el-col v-if="can('orders:view')" :span="can('flows:view') ? 16 : 24">
        <el-card>
          <template #header>
            <span>最近订单</span>
          </template>
          <el-table :data="recent" stripe>
            <el-table-column prop="orderNo" label="订单号" width="160" />
            <el-table-column label="业务" width="150">
              <template #default="{ row }">{{ orderBizLabel(row) }}</template>
            </el-table-column>
            <el-table-column prop="customerName" label="客户" width="80" />
            <el-table-column label="来源" width="80">
              <template #default>
                <el-tag size="small" type="primary" effect="plain">App</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <StatusTag :status="row.status" />
              </template>
            </el-table-column>
            <el-table-column label="用户侧状态" width="110">
              <template #default="{ row }">{{ labelCStatus(row.status) }}</template>
            </el-table-column>
            <el-table-column prop="createdAt" label="提交时间" min-width="160" />
            <el-table-column label="操作" width="80" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" @click="$router.push(`/orders/${row.id}`)">详情</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col v-if="can('flows:view')" :span="8">
        <el-card>
          <template #header>
            <span>业务流转</span>
          </template>
          <div class="pipe">
            <div class="node">
              <div class="k">下单</div>
              <div class="v">用户提交号卡 / 宽带订单</div>
            </div>
            <div class="arrow">↓</div>
            <div class="node">
              <div class="k">运营</div>
              <div class="v">订单、套餐、商家与师傅管理</div>
            </div>
            <div class="arrow">↓</div>
            <div class="node">
              <div class="k">履约</div>
              <div class="v">商家接单派单，师傅上门办理</div>
            </div>
          </div>
          <el-button type="primary" plain style="width: 100%; margin-top: 12px" @click="$router.push('/flows')">
            查看业务线
          </el-button>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Box, List, Tickets, UserFilled, WarningFilled } from '@element-plus/icons-vue'
import StatusTag from '@/components/StatusTag.vue'
import StatBoard from '@/components/StatBoard.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { labelCStatus, orderBizLabel } from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const s = computed(() => store.stats)
const recent = computed(() => [...store.orders].sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1)).slice(0, 8))

const cards = computed(() => {
  const list = []
  if (can('orders:view')) {
    list.push(
      { label: '全部订单', value: s.value.total, desc: '全部业务订单', color: '#1a73e8', tint: 'rgba(26,115,232,.12)', icon: List },
      { label: '待接单', value: s.value.pending, desc: '等待商家接单', color: '#1e88e5', tint: 'rgba(30,136,229,.12)', icon: Tickets },
      { label: '进行中', value: s.value.processing, desc: '履约处理中', color: '#ef6c00', tint: 'rgba(239,108,0,.12)', icon: Box },
      { label: '已完成', value: s.value.done, desc: '办理完成', color: '#2e7d32', tint: 'rgba(46,125,50,.12)', icon: Tickets },
    )
  }
  if (can('agents:view')) {
    list.push({ label: '入驻代理商', value: s.value.agentActive, desc: '平台合作中的代理', color: '#1565c0', tint: 'rgba(21,101,192,.12)', icon: UserFilled })
  }
  if (can('warehouse:view')) {
    list.push(
      { label: '仓库件数', value: s.value.warehouseQty, desc: `${s.value.warehouseSku} 个 SKU`, color: '#00897b', tint: 'rgba(0,137,123,.12)', icon: Box },
      { label: '库存偏低', value: s.value.stockLow, desc: '低于安全库存', color: '#c62828', tint: 'rgba(198,40,40,.12)', icon: WarningFilled },
    )
  }
  if (can('stock:view')) {
    list.push(
      { label: '入库单', value: s.value.stockIn, desc: '累计入库记录', color: '#2e7d32', tint: 'rgba(46,125,50,.12)', icon: Box },
      { label: '出库单', value: s.value.stockOut, desc: '累计出库记录', color: '#ef6c00', tint: 'rgba(239,108,0,.12)', icon: Box },
    )
  }
  return list
})
</script>

<style scoped lang="scss">
.stat-card {
  margin-bottom: 16px;
  overflow: hidden;
  :deep(.el-card__body) {
    padding: 16px 18px !important;
  }
}
.stat {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  position: relative;
  &::before {
    content: '';
    position: absolute;
    left: -18px;
    top: -6px;
    bottom: -6px;
    width: 4px;
    border-radius: 0 4px 4px 0;
    background: var(--accent, #1a73e8);
  }
  .label {
    color: #7b8898;
    font-size: 13px;
  }
  .value {
    margin-top: 8px;
    font-size: 28px;
    font-weight: 750;
    letter-spacing: 0.4px;
    color: var(--accent, #1c2430);
  }
  .desc {
    margin-top: 6px;
    font-size: 12px;
    color: #a0aab6;
  }
  .icon {
    width: 42px;
    height: 42px;
    border-radius: 12px;
    display: grid;
    place-items: center;
    color: var(--accent);
    flex: none;
  }
  &.compact .value.sm {
    font-size: 22px;
    color: #1c2430;
  }
}
.pipe {
  .node {
    background: linear-gradient(180deg, #f7faff, #f2f6fb);
    border: 1px solid #e8eef6;
    border-radius: 12px;
    padding: 12px;
  }
  .k {
    font-weight: 750;
    color: #1a73e8;
    font-size: 13px;
  }
  .v {
    margin-top: 4px;
    font-size: 12px;
    color: #5a6b7d;
    line-height: 1.5;
  }
  .arrow {
    text-align: center;
    color: #c0c4cc;
    padding: 4px 0;
  }
}
</style>
