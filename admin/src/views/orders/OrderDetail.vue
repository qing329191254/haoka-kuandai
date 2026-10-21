<template>
  <div v-if="order">
    <el-page-header @back="$router.push('/orders')" :content="`订单详情 · ${order.orderNo}`" style="margin-bottom: 16px" />

    <el-row :gutter="16">
      <el-col :span="16">
        <el-card>
          <template #header>
            <div class="hd">
              <span>基本信息</span>
              <div v-if="can('orders:edit')">
                <el-button size="small" @click="openRemark">备注</el-button>
                <el-button
                  size="small"
                  type="danger"
                  plain
                  :disabled="order.status === 'done' || order.status === 'cancelled' || order.status === 'failed'"
                  @click="openCancel"
                >
                  取消订单
                </el-button>
              </div>
            </div>
          </template>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="订单号">{{ order.orderNo }}</el-descriptions-item>
            <el-descriptions-item label="来源">
              <el-tag size="small" type="primary" effect="plain">App</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="业务类型">{{ orderBizLabel(order) }}</el-descriptions-item>
            <el-descriptions-item label="是否新开卡">{{ order.needNewCard ? '是' : '否' }}</el-descriptions-item>
            <el-descriptions-item label="运营状态">
              <StatusTag :status="order.status" />
            </el-descriptions-item>
            <el-descriptions-item label="用户侧状态">{{ C_STATUS_LABEL[order.status] }}</el-descriptions-item>
            <el-descriptions-item label="运营商 / WIFI 公司">{{ order.carrier }}</el-descriptions-item>
            <el-descriptions-item label="套餐 / 说明">{{ order.productName }}</el-descriptions-item>
            <el-descriptions-item v-if="order.orderIntent" label="客户意向">{{ order.orderIntent }}</el-descriptions-item>
            <el-descriptions-item v-if="order.phoneBrand" label="手机品牌">{{ order.phoneBrand }}</el-descriptions-item>
            <el-descriptions-item v-if="order.priceRange" label="价格区间">{{ order.priceRange }}</el-descriptions-item>
            <el-descriptions-item v-if="order.wifiDeviceType" label="WIFI 设备类型">{{ order.wifiDeviceType }}</el-descriptions-item>
            <el-descriptions-item v-if="order.wifiBizMode" label="WIFI 业务模式">{{ order.wifiBizMode }}</el-descriptions-item>
            <el-descriptions-item label="客户">{{ order.customerName }}</el-descriptions-item>
            <el-descriptions-item label="手机号">{{ order.customerPhone }}</el-descriptions-item>
            <el-descriptions-item label="区域">{{ order.region }}</el-descriptions-item>
            <el-descriptions-item label="地址" :span="2">{{ order.address }}</el-descriptions-item>
            <el-descriptions-item label="履约商家">{{ order.merchantName || '待接单' }}</el-descriptions-item>
            <el-descriptions-item label="上门师傅">
              {{ skipTechDispatch(order.bizType) ? '无需派单' : order.technicianName || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="提交时间">{{ order.createdAt }}</el-descriptions-item>
            <el-descriptions-item label="更新时间">{{ order.updatedAt }}</el-descriptions-item>
            <el-descriptions-item label="佣金">{{ order.commission != null ? `¥${order.commission}` : '-' }}</el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">{{ order.remark || '-' }}</el-descriptions-item>
            <el-descriptions-item v-if="order.followUpReason" label="跟进原因" :span="2">
              <el-text type="warning">{{ order.followUpReason }}</el-text>
            </el-descriptions-item>
            <el-descriptions-item v-if="order.nextFollowUpAt" label="下次联系">{{ order.nextFollowUpAt }}</el-descriptions-item>
            <el-descriptions-item v-if="order.needsDispatch" label="需上门">是</el-descriptions-item>
            <el-descriptions-item v-if="order.status === 'failed' || order.failReason" label="失败说明" :span="2">
              <el-text type="danger">{{ order.failReason || '-' }}</el-text>
            </el-descriptions-item>
            <el-descriptions-item v-if="order.deliveryPhotos?.length" label="交付照片" :span="2">
              <div class="photos">
                <el-image
                  v-for="(src, i) in order.deliveryPhotos"
                  :key="i"
                  :src="src"
                  :preview-src-list="order.deliveryPhotos"
                  :initial-index="i"
                  fit="cover"
                  class="photo"
                />
              </div>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <el-card v-if="order.followUpLogs?.length" header="跟进记录" style="margin-top: 16px">
          <el-timeline>
            <el-timeline-item v-for="(log, i) in order.followUpLogs" :key="i" :timestamp="log.time" placement="top">
              {{ log.actor ? `${log.actor} · ` : '' }}{{ log.note }}
            </el-timeline-item>
          </el-timeline>
        </el-card>

        <el-card header="流转日志" style="margin-top: 16px">
          <el-timeline>
            <el-timeline-item
              v-for="(log, i) in [...order.logs].reverse()"
              :key="i"
              :timestamp="log.time"
              placement="top"
            >
              <el-tag size="small" effect="plain" style="margin-right: 8px">{{ CHANNEL_LABEL[log.channel] }}</el-tag>
              <span>{{ log.actor }} · {{ log.action }}</span>
            </el-timeline-item>
          </el-timeline>
        </el-card>
      </el-col>

      <el-col :span="8">
        <el-card header="运营流程">
          <el-steps direction="vertical" :active="opsActive" finish-status="success" :process-status="processStatus">
            <el-step v-for="(s, i) in FLOW_STEPS[order.bizType]" :key="i" :title="s" />
          </el-steps>
        </el-card>
        <el-card header="用户侧步骤" style="margin-top: 16px">
          <el-steps direction="vertical" :active="cActive < 0 ? 0 : cActive" finish-status="success">
            <el-step v-for="(s, i) in C_FLOW_STEPS[order.bizType]" :key="i" :title="s" />
          </el-steps>
        </el-card>
        <el-card header="履约节点" style="margin-top: 16px">
          <div v-for="n in MP_FLOW_NODES[order.bizType]" :key="n.role" class="mp-node">
            <div class="role">{{ n.role }}</div>
            <div class="action">{{ n.action }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
  <el-skeleton v-else-if="loading" rows="6" animated />
  <el-empty v-else description="订单不存在" />
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import StatusTag from '@/components/StatusTag.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import {
  C_FLOW_STEPS,
  C_STATUS_LABEL,
  CHANNEL_LABEL,
  FLOW_STEPS,
  MP_FLOW_NODES,
  cFlowActive,
  opsFlowActive,
  orderBizLabel,
  skipTechDispatch,
} from '@/types/order'

const route = useRoute()
const store = useAdminStore()
const { can } = usePermission()
const loading = ref(false)
const order = computed(() => store.getOrder(String(route.params.id)))

onMounted(async () => {
  loading.value = true
  await store.fetchOrder(String(route.params.id))
  loading.value = false
})
const opsActive = computed(() => (order.value ? opsFlowActive(order.value.bizType, order.value.status) : 0))
const cActive = computed(() => (order.value ? cFlowActive(order.value.bizType, order.value.status) : 0))
const processStatus = computed(() =>
  order.value?.status === 'cancelled' ? 'error' : 'process',
)

async function openRemark() {
  if (!order.value) return
  const { value } = await ElMessageBox.prompt('填写运营备注', '备注订单', {
    inputValue: order.value.remark || '',
    confirmButtonText: '保存',
    cancelButtonText: '取消',
  }).catch(() => ({ value: null as string | null }))
  if (value == null) return
  try {
    await store.remarkOrder(order.value.id, value)
    ElMessage.success('已保存备注')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '保存失败')
  }
}

async function openCancel() {
  if (!order.value) return
  const { value } = await ElMessageBox.prompt('请填写取消原因', '取消订单', {
    confirmButtonText: '确认取消',
    cancelButtonText: '返回',
    type: 'warning',
    inputPlaceholder: '如：客户主动取消',
  }).catch(() => ({ value: null as string | null }))
  if (value == null) return
  try {
    await store.cancelOrder(order.value.id, value)
    ElMessage.success('订单已取消')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '取消失败')
  }
}
</script>

<style scoped lang="scss">
.hd {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.mp-node {
  padding: 10px 0;
  border-bottom: 1px solid #f0f0f0;
  &:last-child {
    border-bottom: none;
  }
  .role {
    font-weight: 700;
    font-size: 13px;
    color: #1e88e5;
  }
  .action {
    margin-top: 4px;
    font-size: 13px;
    color: #606266;
    line-height: 1.5;
  }
}
.photos {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.photo {
  width: 120px;
  height: 80px;
  border-radius: 8px;
  overflow: hidden;
}
</style>
