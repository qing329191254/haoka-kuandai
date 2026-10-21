<template>
  <div class="stat-board">
    <el-row v-if="can('orders:view')" :gutter="16">
      <el-col :span="16">
        <el-card shadow="never">
          <template #header>
            <div class="head">
              <span>订单趋势</span>
              <span class="sub">近 14 天 · 按业务类型</span>
            </div>
          </template>
          <v-chart class="chart lg" :option="trendOption" autoresize />
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never">
          <template #header>
            <div class="head">
              <span>状态占比</span>
              <span class="sub">用户侧状态</span>
            </div>
          </template>
          <v-chart class="chart lg" :option="statusOption" autoresize />
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="row">
      <el-col v-if="can('orders:view')" :span="can('warehouse:view') ? 8 : 12">
        <el-card shadow="never">
          <template #header>
            <div class="head">
              <span>业务构成</span>
              <span class="sub">号卡 / 宽带</span>
            </div>
          </template>
          <v-chart class="chart" :option="bizOption" autoresize />
        </el-card>
      </el-col>
      <el-col v-if="can('orders:view')" :span="can('warehouse:view') ? 8 : 12">
        <el-card shadow="never">
          <template #header>
            <div class="head">
              <span>区域订单</span>
              <span class="sub">按装机区域</span>
            </div>
          </template>
          <v-chart class="chart" :option="regionOption" autoresize />
        </el-card>
      </el-col>
      <el-col v-if="can('warehouse:view')" :span="can('orders:view') ? 8 : 24">
        <el-card shadow="never">
          <template #header>
            <div class="head">
              <span>库存对比</span>
              <span class="sub">号卡实体卡 · 当前 vs 安全库存</span>
            </div>
          </template>
          <v-chart class="chart" :option="stockOption" autoresize />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import type { ComposeOption } from 'echarts/core'
import type { BarSeriesOption, LineSeriesOption, PieSeriesOption } from 'echarts/charts'
import type { GridComponentOption, LegendComponentOption, TooltipComponentOption } from 'echarts/components'
import '@/charts/register'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { BIZ_TYPE_LABEL, C_STATUS_LABEL, type BizType, type OrderStatus } from '@/types/order'

type ECOption = ComposeOption<
  BarSeriesOption | LineSeriesOption | PieSeriesOption | GridComponentOption | LegendComponentOption | TooltipComponentOption
>

const store = useAdminStore()
const { can } = usePermission()

const PALETTE = ['#1a73e8', '#14b8a6', '#e8b923', '#2e7d32', '#ef6c00', '#7c4dff', '#00897b', '#c62828']
const STATUS_COLOR: Record<OrderStatus, string> = {
  listed: '#1a73e8',
  merchant_accepted: '#3d9be8',
  dispatched: '#64b5f6',
  tech_accepted: '#ef6c00',
  boss_opened: '#e8b923',
  installing: '#8d6e63',
  follow_up: '#f57c00',
  done: '#2e7d32',
  failed: '#f57c00',
  cancelled: '#90a4ae',
}

const axisLabel = { color: '#7b8898', fontSize: 11 }
const splitLine = { lineStyle: { color: '#eef2f7', type: 'dashed' as const } }
const tooltip = {
  backgroundColor: 'rgba(7, 22, 40, 0.92)',
  borderWidth: 0,
  textStyle: { color: '#fff', fontSize: 12 },
}

function pad(n: number) {
  return String(n).padStart(2, '0')
}

function addDays(iso: string, delta: number) {
  const [y, m, d] = iso.split('-').map(Number)
  const dt = new Date(y, m - 1, d)
  dt.setDate(dt.getDate() + delta)
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`
}

function lastDays(n: number) {
  const stamps = store.orders.map((o) => o.createdAt.slice(0, 10)).sort()
  const end = stamps.at(-1) || new Date().toISOString().slice(0, 10)
  return Array.from({ length: n }, (_, i) => addDays(end, i - n + 1))
}

const trendOption = computed<ECOption>(() => {
  const days = lastDays(14)
  const types: BizType[] = [
    'haoka',
    'contract_phone',
    'broadband_naked',
    'broadband_new_card',
    'broadband_no_card',
    'wifi',
    'cpe',
    'stock',
  ]
  return {
    color: PALETTE,
    tooltip: { ...tooltip, trigger: 'axis' },
    legend: {
      top: 0,
      right: 8,
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      textStyle: { color: '#5a6b7d', fontSize: 12 },
    },
    grid: { left: 40, right: 16, top: 40, bottom: 28 },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: days.map((d) => d.slice(5)),
      axisLine: { lineStyle: { color: '#d7e0ea' } },
      axisLabel,
    },
    yAxis: { type: 'value', minInterval: 1, splitLine, axisLabel },
    series: types.map((type, i) => {
      const color = PALETTE[i]
      return {
        name: BIZ_TYPE_LABEL[type],
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 7,
        showSymbol: false,
        lineStyle: { width: 2.5, color },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: `${color}4D` },
              { offset: 1, color: `${color}05` },
            ],
          },
        },
        emphasis: { focus: 'series' },
        data: days.map((day) => store.orders.filter((o) => o.createdAt.startsWith(day) && o.bizType === type).length),
      }
    }),
  }
})

const statusOption = computed<ECOption>(() => {
  const counts = new Map<OrderStatus, number>()
  for (const o of store.orders) counts.set(o.status, (counts.get(o.status) || 0) + 1)
  const data = [...counts.entries()].map(([status, value]) => ({
    name: C_STATUS_LABEL[status],
    value,
    itemStyle: { color: STATUS_COLOR[status] },
  }))
  return {
    tooltip: { ...tooltip, trigger: 'item', formatter: '{b}<br/>{c} 单（{d}%）' },
    legend: {
      bottom: 0,
      left: 'center',
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      textStyle: { color: '#5a6b7d', fontSize: 11 },
    },
    series: [
      {
        type: 'pie',
        radius: ['46%', '68%'],
        center: ['50%', '44%'],
        avoidLabelOverlap: true,
        itemStyle: { borderColor: '#fff', borderWidth: 2 },
        label: { show: false },
        data,
      },
    ],
  }
})

const bizOption = computed<ECOption>(() => {
  const types: BizType[] = [
    'haoka',
    'contract_phone',
    'broadband_naked',
    'broadband_new_card',
    'broadband_no_card',
    'wifi',
    'cpe',
    'stock',
  ]
  return {
    color: PALETTE,
    tooltip: { ...tooltip, trigger: 'item', formatter: '{b}<br/>{c} 单（{d}%）' },
    legend: {
      bottom: 0,
      left: 'center',
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      textStyle: { color: '#5a6b7d', fontSize: 11 },
    },
    series: [
      {
        type: 'pie',
        radius: ['46%', '68%'],
        center: ['50%', '44%'],
        itemStyle: { borderColor: '#fff', borderWidth: 2, borderRadius: 6 },
        label: { formatter: '{d}%', color: '#5a6b7d', fontSize: 11 },
        data: types.map((type) => ({
          name: BIZ_TYPE_LABEL[type],
          value: store.orders.filter((o) => o.bizType === type).length,
        })),
      },
    ],
  }
})

const regionOption = computed<ECOption>(() => {
  const counts = new Map<string, number>()
  for (const o of store.orders) counts.set(o.region, (counts.get(o.region) || 0) + 1)
  const rows = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8)
  return {
    color: ['#1a73e8'],
    tooltip: { ...tooltip, trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: 56, right: 16, top: 12, bottom: 28 },
    xAxis: { type: 'value', minInterval: 1, splitLine, axisLabel },
    yAxis: {
      type: 'category',
      inverse: true,
      data: rows.map(([name]) => name),
      axisLabel,
      axisLine: { show: false },
      axisTick: { show: false },
    },
    series: [
      {
        type: 'bar',
        barWidth: 12,
        data: rows.map(([, n]) => n),
        itemStyle: {
          borderRadius: [0, 8, 8, 0],
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 1,
            y2: 0,
            colorStops: [
              { offset: 0, color: '#3d9be8' },
              { offset: 1, color: '#1a73e8' },
            ],
          },
        },
      },
    ],
  }
})

const stockOption = computed<ECOption>(() => {
  const rows = [...store.warehouse].sort((a, b) => b.stock - a.stock).slice(0, 6)
  return {
    color: ['#1a73e8', '#e8b923'],
    tooltip: { ...tooltip, trigger: 'axis', axisPointer: { type: 'shadow' } },
    legend: {
      top: 0,
      right: 0,
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      textStyle: { color: '#5a6b7d', fontSize: 12 },
    },
    grid: { left: 88, right: 16, top: 32, bottom: 12 },
    xAxis: { type: 'value', minInterval: 1, splitLine, axisLabel },
    yAxis: {
      type: 'category',
      inverse: true,
      data: rows.map((w) => (w.productName.length > 8 ? `${w.productName.slice(0, 8)}…` : w.productName)),
      axisLabel,
      axisLine: { show: false },
      axisTick: { show: false },
    },
    series: [
      {
        name: '当前库存',
        type: 'bar',
        barWidth: 8,
        data: rows.map((w) => w.stock),
        itemStyle: { borderRadius: [0, 6, 6, 0], color: '#1a73e8' },
      },
      {
        name: '安全库存',
        type: 'bar',
        barWidth: 8,
        data: rows.map((w) => w.safetyStock),
        itemStyle: { borderRadius: [0, 6, 6, 0], color: '#e8b923' },
      },
    ],
  }
})
</script>

<style scoped lang="scss">
.stat-board {
  margin-top: 4px;
}
.row {
  margin-top: 16px;
}
.head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  .sub {
    font-size: 12px;
    color: #8a97a8;
    font-weight: 400;
  }
}
.chart {
  height: 260px;
  width: 100%;
  &.lg {
    height: 300px;
  }
}
</style>
