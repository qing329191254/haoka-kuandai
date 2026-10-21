<template>
  <view class="page page-shell dense" v-if="session">
    <view class="card surface">
      <view class="field">
        <text class="label">姓名</text>
        <input v-model="form.name" class="input" placeholder="师傅姓名" />
      </view>
      <view class="field">
        <text class="label">手机号</text>
        <input v-model="form.phone" type="number" maxlength="11" class="input" placeholder="用于师傅端登录" />
      </view>
      <RegionPicker
        :value="{ province: form.province, city: form.city, district: form.district }"
        @confirm="onRegionConfirm"
      >
        <view class="field">
          <text class="label">服务区域</text>
          <text class="picker">{{ regionText || '请选择省 / 市 / 区' }}</text>
        </view>
      </RegionPicker>
      <view class="field">
        <text class="label">可接技能</text>
        <checkbox-group @change="onSkills">
          <label class="chk"><checkbox value="haoka" :checked="form.skills.includes('haoka')" color="#1e88e5" />号卡</label>
          <label class="chk"
            ><checkbox value="contract_phone" :checked="form.skills.includes('contract_phone')" color="#1e88e5" />合约机</label
          >
          <label class="chk"
            ><checkbox
              value="broadband_new_card"
              :checked="form.skills.includes('broadband_new_card')"
              color="#1e88e5"
            />融合宽带（新开卡）</label
          >
          <label class="chk"><checkbox value="wifi" :checked="form.skills.includes('wifi')" color="#1e88e5" />WIFI 设备</label>
          <label class="chk"><checkbox value="cpe" :checked="form.skills.includes('cpe')" color="#1e88e5" />CPE</label>
          <label class="chk"
            ><checkbox value="stock" :checked="form.skills.includes('stock')" color="#1e88e5" />存量业务</label
          >
        </checkbox-group>
      </view>
      <view class="field">
        <text class="label">状态</text>
        <switch :checked="form.status === 'active'" color="#1e88e5" @change="onStatus" />
        <text class="sw">{{ form.status === 'active' ? '在岗' : '停用' }}</text>
      </view>
    </view>
    <button class="btn btn-primary" @click="save">保存</button>
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import RegionPicker from '@/components/RegionPicker.vue'
import { fetchTechnicians, saveTechnician } from '@/store/technicians'
import type { TechSkill } from '@/data/technicians'
import { showToast, withLoading } from '@/store/feedback'
import { request } from '@/api/http'
import { requireRole, type MpSession } from '@/store/session'
import { regionLabel, type RegionSelection } from '@/utils/chinaRegions'

const session = ref<MpSession | null>(null)
const editId = ref('')
const form = reactive({
  name: '',
  phone: '',
  province: '',
  city: '',
  district: '',
  skills: ['haoka'] as TechSkill[],
  status: 'active' as 'active' | 'disabled',
})

const regionText = computed(() =>
  form.province ? regionLabel({ province: form.province, city: form.city, district: form.district }) : '',
)

onLoad(async (q) => {
  session.value = requireRole('merchant')
  if (!session.value) return
  editId.value = String(q?.id || '')
  try {
    const me = await request<{ province?: string; city?: string; district?: string }>({ url: '/api/mp/me' })
    if (!editId.value) {
      if (me.province) form.province = me.province
      if (me.city) form.city = me.city
      if (me.district) form.district = me.district
    }
  } catch {
    /* 新建时可不预填 */
  }
  if (editId.value) {
    try {
      const list = await fetchTechnicians()
      const t = list.find((x) => x.id === editId.value)
      if (t) {
        form.name = t.name
        form.phone = t.phone
        form.province = t.province
        form.city = t.city
        form.district = t.district
        form.skills = [...t.skills]
        form.status = t.status
      }
    } catch {
      /* ignore */
    }
  }
})

function onSkills(e: { detail: { value: string[] } }) {
  form.skills = e.detail.value as TechSkill[]
}

function onStatus(e: Event) {
  const value = Boolean((e as Event & { detail?: { value?: boolean } }).detail?.value)
  form.status = value ? 'active' : 'disabled'
}

function onRegionConfirm(sel: RegionSelection) {
  form.province = sel.province
  form.city = sel.city
  form.district = sel.district
}

async function save() {
  if (!session.value?.merchantId) return
  if (!form.name.trim() || !/^1\d{10}$/.test(form.phone.trim())) {
    showToast('请填写姓名和正确手机号', { type: 'error' })
    return
  }
  if (!form.province || !form.city || !form.district) {
    showToast('请选择服务区域', { type: 'error' })
    return
  }
  try {
    await withLoading(
      () =>
        saveTechnician({
          id: editId.value || undefined,
          name: form.name,
          phone: form.phone,
          province: form.province,
          city: form.city,
          district: form.district,
          skills: form.skills.length ? form.skills : ['haoka'],
          status: form.status,
        }),
      '提交中…',
    )
  } catch (e) {
    showToast(e instanceof Error ? e.message : '保存失败', { type: 'error' })
    return
  }
  showToast('已保存', { type: 'success', duration: 800 })
  setTimeout(() => uni.navigateBack(), 800)
}
</script>

<style scoped>
.card {
  padding: 8rpx 24rpx 24rpx;
}
.field {
  padding: 20rpx 0;
  border-bottom: 1rpx solid #e8eef5;
}
.label {
  display: block;
  font-size: 24rpx;
  color: #8a94a6;
  margin-bottom: 10rpx;
}
.input {
  height: 64rpx;
  font-size: 28rpx;
}
.picker {
  font-size: 28rpx;
  color: #122033;
}
.chk {
  display: block;
  margin: 10rpx 0;
  font-size: 26rpx;
}
.sw {
  margin-left: 12rpx;
  font-size: 26rpx;
  color: #122033;
  vertical-align: middle;
}
.btn {
  margin-top: 28rpx;
  height: 92rpx;
  line-height: 92rpx;
  font-size: 30rpx;
}
</style>
