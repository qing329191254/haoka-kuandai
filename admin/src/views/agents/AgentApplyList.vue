<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>代理入驻申请</span>
        <el-tag v-if="pendingCount" type="warning" effect="plain">待审 {{ pendingCount }}</el-tag>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="审核状态" style="width: 140px">
        <el-option label="待审核" value="pending" />
        <el-option label="已通过" value="approved" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="手机号 / 联系人 / 公司" style="width: 260px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="createdAt" label="申请时间" width="170" />
      <el-table-column prop="name" label="公司 / 门店" min-width="140" />
      <el-table-column prop="contact" label="联系人" width="90" />
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column label="区域 / 规模" min-width="160">
        <template #default="{ row }">
          {{ agentRegionLabel(row) }}
          <div class="sub">{{ row.scaleLabel || '' }}</div>
        </template>
      </el-table-column>
      <el-table-column label="押金" width="110">
        <template #default="{ row }">
          <el-tag :type="row.depositPaid ? 'success' : 'info'" size="small" effect="plain">
            {{ row.depositPaid ? `已缴 ¥${row.depositAmount}` : '未缴' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="电子签" width="100">
        <template #default="{ row }">
          <el-tag :type="row.contractSigned ? 'success' : 'info'" size="small" effect="plain">
            {{ row.contractSigned ? '已签' : '未签' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="statusType(row.status)" size="small">{{ statusLabel(row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('agents:edit')" label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openDetail(row)">详情</el-button>
          <template v-if="row.status === 'pending'">
            <el-button link type="success" :disabled="!canApprove(row)" @click="onApprove(row)">通过</el-button>
            <el-button link type="danger" @click="onReject(row)">驳回</el-button>
          </template>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-drawer v-model="detailVisible" title="申请详情" size="460px">
      <template v-if="current">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="公司 / 门店">{{ current.name }}</el-descriptions-item>
          <el-descriptions-item label="联系人">{{ current.contact }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ current.phone }}</el-descriptions-item>
          <el-descriptions-item label="合作区域">{{ agentRegionLabel(current) }}</el-descriptions-item>
          <el-descriptions-item label="合作规模">{{ current.scaleLabel || '-' }}</el-descriptions-item>
          <el-descriptions-item label="详细地址">{{ current.address || '-' }}</el-descriptions-item>
          <el-descriptions-item label="微信">{{ current.wechat || '-' }}</el-descriptions-item>
          <el-descriptions-item label="备用电话">{{ current.backupPhone || '-' }}</el-descriptions-item>
          <el-descriptions-item label="证件号码">{{ current.idNo || '-' }}</el-descriptions-item>
          <el-descriptions-item label="证件附件">{{ current.licenseName || '未上传' }}</el-descriptions-item>
          <el-descriptions-item label="押金">
            {{ current.depositPaid ? `已缴 ¥${current.depositAmount}` : '未缴纳' }}
            <span v-if="current.depositPaidAt">（{{ current.depositPaidAt }}）</span>
          </el-descriptions-item>
          <el-descriptions-item label="电子签合同">
            {{ current.contractSigned ? '已签署' : '未签署' }}
            <template v-if="current.contractSigned">
              · {{ current.contractNo }} · {{ current.signerName }}
              <span v-if="current.contractSignedAt">（{{ current.contractSignedAt }}）</span>
            </template>
          </el-descriptions-item>
          <el-descriptions-item label="备注">{{ current.remark || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">{{ statusLabel(current.status) }}</el-descriptions-item>
          <el-descriptions-item v-if="current.rejectReason" label="驳回原因">{{ current.rejectReason }}</el-descriptions-item>
          <el-descriptions-item label="申请时间">{{ current.createdAt }}</el-descriptions-item>
          <el-descriptions-item v-if="current.reviewedAt" label="审核时间">{{ current.reviewedAt }}</el-descriptions-item>
        </el-descriptions>
        <el-alert
          v-if="current.status === 'pending' && !canApprove(current)"
          style="margin-top: 16px"
          type="warning"
          :closable="false"
          title="须代理在 App 完成电子签与押金支付后，方可审核通过"
        />
        <div v-if="can('agents:edit') && current.status === 'pending'" class="actions">
          <el-button type="success" :disabled="!canApprove(current)" @click="onApprove(current)">通过</el-button>
          <el-button type="danger" plain @click="onReject(current)">驳回</el-button>
        </div>
      </template>
    </el-drawer>
  </el-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { includesKw, usePager } from '@/composables/usePager'
import { agentRegionLabel, type AgentApplication, type AgentApplyStatus } from '@/types/stock'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<AgentApplyStatus>()
const keyword = ref('')
const pendingCount = computed(() => store.agentApplications.filter((a) => a.status === 'pending').length)

const { page, pageSize, filtered, paged } = usePager(() =>
  store.agentApplications.filter((a) => {
    if (status.value && a.status !== status.value) return false
    const k = keyword.value.trim()
    return includesKw(a.phone, k) || includesKw(a.contact, k) || includesKw(a.name, k)
  }),
)
watch([status, keyword], () => {
  page.value = 1
})

const detailVisible = ref(false)
const current = ref<AgentApplication | null>(null)

function statusLabel(s: AgentApplyStatus) {
  return s === 'pending' ? '待审核' : s === 'approved' ? '已通过' : '已驳回'
}
function statusType(s: AgentApplyStatus) {
  return s === 'pending' ? 'warning' : s === 'approved' ? 'success' : 'danger'
}
function canApprove(row: AgentApplication) {
  return row.depositPaid && row.contractSigned
}

function openDetail(row: AgentApplication) {
  current.value = row
  detailVisible.value = true
}

async function onApprove(row: AgentApplication) {
  if (!canApprove(row)) {
    ElMessage.warning('须先完成电子签与押金')
    return
  }
  try {
    await ElMessageBox.confirm(
      `确认通过「${row.name}」？将核验电子签合同与押金，通过后写入代理商列表。`,
      '审核通过',
      { type: 'success', confirmButtonText: '通过' },
    )
  } catch {
    return
  }
  const err = await store.approveApplication(row.id)
  if (err) {
    ElMessage.warning(err)
    return
  }
  ElMessage.success('已通过，已加入代理商')
  detailVisible.value = false
}

async function onReject(row: AgentApplication) {
  try {
    const { value } = await ElMessageBox.prompt('请填写驳回原因', '驳回申请', {
      inputPlaceholder: '例如：证件不清晰 / 合同主体不符',
      confirmButtonText: '驳回',
      type: 'warning',
      inputValidator: (v) => (!!v?.trim() ? true : '请填写原因'),
    })
    const err = await store.rejectApplication(row.id, value)
    if (err) {
      ElMessage.warning(err)
      return
    }
    ElMessage.success('已驳回')
    detailVisible.value = false
  } catch {
    /* cancel */
  }
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}
.toolbar {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}
.actions {
  margin-top: 20px;
  display: flex;
  gap: 12px;
}
.sub {
  font-size: 12px;
  color: #7b8898;
  margin-top: 2px;
}
</style>
