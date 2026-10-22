<template>
  <el-card>
    <template #header>
      <div class="hd">
        <div>
          <div>客服配置</div>
          <p class="sub">热线展示给用户；快捷问题出现在 App 聊天输入框上方，一点即发并可自动回复。</p>
        </div>
        <el-button v-if="can('service:edit')" type="primary" @click="saveCfg">保存配置</el-button>
      </div>
    </template>
    <el-form label-width="88px">
      <div class="cfg-grid">
        <el-form-item label="客服热线">
          <el-input v-model="cfg.hotline" placeholder="如 400-000-0000" />
        </el-form-item>
        <el-form-item label="服务时间">
          <el-input v-model="cfg.workTime" placeholder="如 工作日 09:00-18:00" />
        </el-form-item>
      </div>
      <el-form-item label="快捷问题">
        <div class="qr-list">
          <p class="qr-hint">
            「问题」是用户点标签发出的内容；「答案」有内容则自动回复，留空则转人工处理。
          </p>
          <div class="qr-grid">
            <div v-for="(item, i) in cfg.quickReplies" :key="i" class="qr-item">
              <div class="qr-hd">
                <span>第 {{ i + 1 }} 条</span>
                <el-button
                  v-if="can('service:edit')"
                  link
                  type="danger"
                  :disabled="cfg.quickReplies.length <= 1"
                  @click="removeReply(i)"
                >
                  删除
                </el-button>
              </div>
              <el-input v-model="item.prompt" placeholder="问题标签（用户点一下发出去的内容）" />
              <el-input
                v-model="item.reply"
                type="textarea"
                resize="none"
                :rows="3"
                placeholder="自动回复内容（可选；留空则转人工）"
                style="margin-top: 8px"
              />
            </div>
          </div>
          <el-button v-if="can('service:edit')" plain @click="addReply">添加一条</el-button>
        </div>
      </el-form-item>
    </el-form>
  </el-card>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { withLoading } from '@/utils/loading'

const store = useAdminStore()
const { can } = usePermission()

const cfg = reactive({
  hotline: '',
  workTime: '',
  quickReplies: [] as { prompt: string; reply: string }[],
})

watch(
  () => store.serviceConfig,
  (value) => {
    cfg.hotline = value.hotline
    cfg.workTime = value.workTime
    cfg.quickReplies = value.quickReplies.map((q) => ({ ...q }))
  },
  { immediate: true },
)

function addReply() {
  cfg.quickReplies.push({ prompt: '', reply: '' })
}

function removeReply(i: number) {
  cfg.quickReplies.splice(i, 1)
}

async function saveCfg() {
  const quickReplies = cfg.quickReplies
    .map((q) => ({ prompt: q.prompt.trim(), reply: q.reply.trim() }))
    .filter((q) => q.prompt)
  if (!quickReplies.length) {
    ElMessage.warning('请至少保留一条快捷问题')
    return
  }
  try {
    await withLoading(
      () =>
        store.saveServiceConfig({
          hotline: cfg.hotline,
          workTime: cfg.workTime,
          quickReplies,
        }),
      '保存中…',
    )
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  ElMessage.success('客服配置已保存')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}
.sub {
  margin: 6px 0 0;
  font-size: 12px;
  line-height: 1.5;
  font-weight: 400;
  color: #909399;
}
.cfg-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 24px;
  max-width: 920px;
}
.qr-list {
  width: 100%;
}
.qr-hint {
  margin: 0 0 10px;
  font-size: 12px;
  line-height: 1.5;
  color: #909399;
}
.qr-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 12px;
}
.qr-item {
  padding: 12px;
  border: 1px solid #e8eef6;
  border-radius: 12px;
  background: #f7faff;
}
.qr-hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  font-size: 12px;
  color: #7b8898;
}
@media (max-width: 1100px) {
  .cfg-grid,
  .qr-grid {
    grid-template-columns: 1fr;
  }
}
</style>
