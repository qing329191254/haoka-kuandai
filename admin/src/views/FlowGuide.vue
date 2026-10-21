<template>
  <div>
    <el-row :gutter="16">
      <el-col :span="8" v-for="type in bizTypes" :key="type" style="margin-bottom: 16px">
        <el-card class="flow-card">
          <template #header>
            <div class="title">{{ BIZ_TYPE_LABEL[type] }}</div>
          </template>

          <div class="block-title">用户侧步骤</div>
          <el-timeline>
            <el-timeline-item v-for="(step, i) in C_FLOW_STEPS[type]" :key="`c-${i}`" :timestamp="`步骤 ${i + 1}`" placement="top">
              {{ step }}
            </el-timeline-item>
          </el-timeline>

          <div class="block-title">运营节点</div>
          <el-timeline>
            <el-timeline-item v-for="(step, i) in FLOW_STEPS[type]" :key="`o-${i}`" :timestamp="`步骤 ${i + 1}`" placement="top">
              {{ step }}
            </el-timeline-item>
          </el-timeline>

          <div class="block-title">履约节点</div>
          <div v-for="n in MP_FLOW_NODES[type]" :key="n.role" class="mp">
            <span class="role">{{ n.role }}</span>
            <span>{{ n.action }}</span>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import {
  BIZ_TYPE_LABEL,
  C_FLOW_STEPS,
  FLOW_STEPS,
  MP_FLOW_NODES,
  type BizType,
} from '@/types/order'

const bizTypes: BizType[] = [
  'haoka',
  'contract_phone',
  'broadband_naked',
  'broadband_new_card',
  'broadband_no_card',
  'wifi',
  'cpe',
  'stock',
]
</script>

<style scoped lang="scss">
.flow-card {
  height: 100%;
  overflow: hidden;
  :deep(.el-card__header) {
    background: linear-gradient(180deg, #f7fbff, #ffffff);
  }
}
.title {
  font-weight: 750;
}
.guide {
  margin-top: 4px;
  font-size: 12px;
  color: #909399;
  font-weight: 400;
  line-height: 1.45;
}
.block-title {
  font-size: 13px;
  font-weight: 600;
  color: #1e88e5;
  margin: 4px 0 12px;
}
.mp {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 10px 0;
  border-bottom: 1px solid #f0f0f0;
  font-size: 13px;
  color: #606266;
  .role {
    font-weight: 700;
    color: #303133;
  }
  &:last-child {
    border-bottom: none;
  }
}
</style>
