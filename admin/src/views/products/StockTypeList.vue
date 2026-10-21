<template>
  <el-card>
    <template #header>
      <div class="hd">
        <span>存量业务类型</span>
        <el-button v-if="can('products:edit')" type="primary" @click="openEdit()">新增业务类型</el-button>
      </div>
    </template>
    <p class="hint">在此添加业务类型后，再到「商品套餐」里为该类型按地级市上架套餐并设置佣金。App「存量业务」会按这里的类型展示。</p>
    <el-table :data="paged" stripe>
      <el-table-column prop="name" label="业务类型" min-width="160" />
      <el-table-column prop="description" label="说明" min-width="220" />
      <el-table-column label="套餐数" width="100">
        <template #default="{ row }">{{ countOf(row.id) }}</template>
      </el-table-column>
      <el-table-column prop="sort" label="排序" width="80" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'active' ? 'success' : 'info'" size="small">
            {{ row.status === 'active' ? '启用' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="can('products:edit')" label="操作" width="180" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link @click="store.toggleById(store.stockBizTypes, row.id)">
            {{ row.status === 'active' ? '停用' : '启用' }}
          </el-button>
          <el-button link type="danger" @click="onRemove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <ListPager v-model:page="page" v-model:page-size="pageSize" :total="store.stockBizTypes.length" />

    <el-dialog v-model="visible" :title="form.id ? '编辑业务类型' : '新增业务类型'" width="480px">
      <el-form :model="form" label-width="88px">
        <el-form-item label="名称">
          <el-input v-model="form.name" placeholder="如：宽带续费" />
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="form.description" type="textarea" resize="none" :rows="2" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort" :min="1" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false">取消</el-button>
        <el-button type="primary" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </el-card>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ListPager from '@/components/ListPager.vue'
import { useAdminStore } from '@/stores/admin'
import { usePermission } from '@/composables/usePermission'
import { usePager } from '@/composables/usePager'
import type { StockBizType } from '@/types/order'

const store = useAdminStore()
const { can } = usePermission()
const { page, pageSize, paged } = usePager(() => [...store.stockBizTypes].sort((a, b) => a.sort - b.sort))

const visible = ref(false)
const form = reactive<StockBizType>({
  id: '',
  name: '',
  description: '',
  status: 'active',
  sort: 1,
})

function countOf(id: string) {
  return store.products.filter((p) => p.stockTypeId === id).length
}

function openEdit(row?: StockBizType) {
  Object.assign(
    form,
    row
      ? { ...row }
      : {
          id: '',
          name: '',
          description: '',
          status: 'active' as const,
          sort: store.stockBizTypes.length + 1,
        },
  )
  visible.value = true
}

async function save() {
  if (!form.name.trim()) {
    ElMessage.warning('请填写业务类型名称')
    return
  }
  try {
    await store.upsertStockBizType({ ...form, id: form.id || `st${Date.now()}` })
  } catch (e) {
    ElMessage.warning(e instanceof Error ? e.message : '保存失败')
    return
  }
  visible.value = false
  ElMessage.success('已保存')
}

async function onRemove(row: StockBizType) {
  try {
    await ElMessageBox.confirm(`删除业务类型「${row.name}」？其下若仍有套餐将无法删除。`, '删除确认', {
      type: 'warning',
    })
  } catch {
    return
  }
  const err = await store.removeStockBizType(row.id)
  if (err) ElMessage.warning(err)
  else ElMessage.success('已删除')
}
</script>

<style scoped>
.hd {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.hint {
  margin: 0 0 12px;
  font-size: 13px;
  color: #7b8898;
  line-height: 1.5;
}
</style>
