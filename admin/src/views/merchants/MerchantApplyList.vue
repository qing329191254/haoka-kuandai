<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>商家入驻申请</span>
        <el-tag v-if="pendingCount" type="warning" effect="plain">待审 {{ pendingCount }}</el-tag>
      </div>
    </template>
    <div class="toolbar">
      <el-select v-model="status" clearable placeholder="审核状态" style="width: 140px">
        <el-option label="待审核" value="pending" />
        <el-option label="已通过" value="approved" />
        <el-option label="已驳回" value="rejected" />
      </el-select>
      <el-input v-model="keyword" clearable placeholder="手机号 / 联系人 / 门店" style="width: 260px" />
    </div>
    <el-table :data="paged" stripe>
      <el-table-column prop="createdAt" label="申请时间" width="170" />
      <el-table-column prop="name" label="门店名称" min-width="140" />
      <el-table-column prop="contact" label="联系人" width="90" />
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column label="服务地区" min-width="180">
        <template #default="{ row }">{{ regionLabel(row) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="statusType(row.status)" size="small">{{ statusLabel(row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('merchants:edit')" label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openDetail(row)">详情</el-button>
          <template v-if="row.status === 'pending'">
            <el-button link type="success" @click="onApprove(row)">通过</el-button>
            <el-button link type="danger" @click="onReject(row)">驳回</el-button>
          </template>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="filtered.length" />

    <el-drawer v-model="detailVisible" title="申请详情" size="440px">
      <template v-if="current">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="门店名称">{{ current.name }}</el-descriptions-item>
          <el-descriptions-item label="联系人">{{ current.contact }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ current.phone }}</el-descriptions-item>
          <el-descriptions-item label="服务地区">{{ regionLabel(current) }}</el-descriptions-item>
          <el-descriptions-item label="详细地址">{{ current.address || '-' }}</el-descriptions-item>
          <el-descriptions-item label="微信">{{ current.wechat || '-' }}</el-descriptions-item>
          <el-descriptions-item label="备用电话">{{ current.backupPhone || '-' }}</el-descriptions-item>
          <el-descriptions-item label="证件号">{{ current.idNo || '-' }}</el-descriptions-item>
          <el-descriptions-item label="证件照片">{{ current.licenseName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="可接业务">{{ bizText(current.bizTypes) }}</el-descriptions-item>
          <el-descriptions-item label="备注">{{ current.remark || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">{{ statusLabel(current.status) }}</el-descriptions-item>
          <el-descriptions-item v-if="current.rejectReason" label="驳回原因">{{ current.rejectReason }}</el-descriptions-item>
          <el-descriptions-item label="申请时间">{{ current.createdAt }}</el-descriptions-item>
          <el-descriptions-item v-if="current.reviewedAt" label="审核时间">{{ current.reviewedAt }}</el-descriptions-item>
        </el-descriptions>
        <div v-if="can('merchants:edit') && current.status === 'pending'" class="actions">
          <el-button type="success" @click="onApprove(current)">通过</el-button>
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
import {
  labelBiz,
  regionLabel,
  type BizType,
  type MerchantApplication,
  type MerchantApplyStatus,
} from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const status = ref<MerchantApplyStatus>()
const keyword = ref('')
const pendingCount = computed(() => store.merchantApplications.filter((a) => a.status === 'pending').length)

const { page, pageSize, filtered, paged } = usePager(() =>
  store.merchantApplications.filter((a) => {
    if (status.value && a.status !== status.value) return false
    const k = keyword.value.trim()
    return includesKw(a.phone, k) || includesKw(a.contact, k) || includesKw(a.name, k)
  }),
)
watch([status, keyword], () => {
  page.value = 1
})

const detailVisible = ref(false)
const current = ref<MerchantApplication | null>(null)

function statusLabel(s: MerchantApplyStatus) {
  return s === 'pending' ? '待审核' : s === 'approved' ? '已通过' : '已驳回'
}
function statusType(s: MerchantApplyStatus) {
  return s === 'pending' ? 'warning' : s === 'approved' ? 'success' : 'danger'
}
function bizText(types: BizType[]) {
  return types.map((t) => labelBiz(t)).join('、') || '-'
}

function openDetail(row: MerchantApplication) {
  current.value = row
  detailVisible.value = true
}

async function onApprove(row: MerchantApplication) {
  try {
    await ElMessageBox.confirm(`通过「${row.name}」的入驻申请？通过后将写入本地商家列表。`, '审核通过', {
      type: 'success',
      confirmButtonText: '通过',
    })
  } catch {
    return
  }
  const err = await store.approveMerchantApplication(row.id)
  if (err) {
    ElMessage.warning(err)
    return
  }
  ElMessage.success('已通过，已加入本地商家')
  detailVisible.value = false
}

async function onReject(row: MerchantApplication) {
  try {
    const { value } = await ElMessageBox.prompt('请填写驳回原因', '驳回申请', {
      inputPlaceholder: '例如：证件不清晰',
      confirmButtonText: '驳回',
      type: 'warning',
      inputValidator: (v) => (!!v?.trim() ? true : '请填写原因'),
    })
    const err = await store.rejectMerchantApplication(row.id, value)
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
</style>
