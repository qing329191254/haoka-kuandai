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
      <view class="field" @click="pickDistrict">
        <text class="label">服务区域</text>
        <text class="picker">{{ form.district || '选择区县' }}</text>
      </view>
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
import { reactive, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import AppFeedback from '@/components/AppFeedback.vue'
import { fetchTechnicians, saveTechnician } from '@/store/technicians'
import type { TechSkill } from '@/data/technicians'
import { showToast } from '@/store/feedback'
import { request } from '@/api/http'
import { requireRole, type MpSession } from '@/store/session'

const session = ref<MpSession | null>(null)
const editId = ref('')
const form = reactive({
  name: '',
  phone: '',
  province: '浙江省',
  city: '杭州市',
  district: '西湖区',
  skills: ['haoka'] as TechSkill[],
  status: 'active' as 'active' | 'disabled',
})

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
    /* 用默认地区 */
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

function pickDistrict() {
  const districts = ['西湖区', '滨江区', '余杭区', '萧山区', '拱墅区', '上城区']
  uni.showActionSheet({
    itemList: districts,
    success(res) {
      form.district = districts[res.tapIndex]
    },
  })
}

async function save() {
  if (!session.value?.merchantId) return
  if (!form.name.trim() || !/^1\d{10}$/.test(form.phone.trim())) {
    showToast('请填写姓名和正确手机号', { type: 'error' })
    return
  }
  try {
    await saveTechnician({
      id: editId.value || undefined,
      name: form.name,
      phone: form.phone,
      province: form.province,
      city: form.city,
      district: form.district,
      skills: form.skills.length ? form.skills : ['haoka'],
      status: form.status,
    })
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
