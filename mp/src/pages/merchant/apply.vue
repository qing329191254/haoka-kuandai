<template>
  <view class="page page-shell dense">
    <view class="card surface">
      <text class="h">商家入驻申请</text>
      <text class="d">提交后由运营后台审核，通过后方可登录接单</text>
    </view>

    <view class="card surface">
      <text class="sec">账号</text>
      <view class="field">
        <text class="label">手机号</text>
        <input v-model="form.phone" type="number" maxlength="11" class="input" placeholder="登录手机号" />
      </view>
      <view class="field">
        <text class="label">短信验证码</text>
        <view class="code-row">
          <input v-model="form.code" type="number" maxlength="6" class="input flex" placeholder="请输入验证码" />
          <button class="code-btn" @click="onCode">获取验证码</button>
        </view>
      </view>
    </view>

    <view class="card surface">
      <text class="sec">门店信息</text>
      <view class="field">
        <text class="label">门店名称</text>
        <input v-model="form.name" class="input" placeholder="公司 / 门店名称" />
      </view>
      <view class="field">
        <text class="label">联系人</text>
        <input v-model="form.contact" class="input" placeholder="联系人姓名" />
      </view>
      <view class="field" @click="pickRegion">
        <text class="label">服务地区</text>
        <text class="picker">{{ regionLabel || '请选择省 / 市 / 区' }}</text>
      </view>
      <view class="field">
        <text class="label">详细地址</text>
        <input v-model="form.address" class="input" placeholder="街道门牌" />
      </view>
      <view class="field">
        <text class="label">微信（选填）</text>
        <input v-model="form.wechat" class="input" placeholder="微信号" />
      </view>
      <view class="field">
        <text class="label">备用电话（选填）</text>
        <input v-model="form.backupPhone" class="input" placeholder="座机或另一手机" />
      </view>
    </view>

    <view class="card surface">
      <text class="sec">业务与资质</text>
      <view class="field">
        <text class="label">可接业务</text>
        <checkbox-group @change="onBiz">
          <label class="chk"><checkbox value="haoka" :checked="bizTypes.includes('haoka')" color="#1e88e5" />号卡</label>
          <label class="chk"><checkbox value="contract_phone" :checked="bizTypes.includes('contract_phone')" color="#1e88e5" />合约机</label>
          <label class="chk"><checkbox value="broadband_naked" :checked="bizTypes.includes('broadband_naked')" color="#1e88e5" />裸宽</label>
          <label class="chk"><checkbox value="broadband_new_card" :checked="bizTypes.includes('broadband_new_card')" color="#1e88e5" />融合宽带（新开卡上门）</label>
          <label class="chk"><checkbox value="broadband_no_card" :checked="bizTypes.includes('broadband_no_card')" color="#1e88e5" />融合宽带（线上办理）</label>
          <label class="chk"><checkbox value="wifi" :checked="bizTypes.includes('wifi')" color="#1e88e5" />WIFI 设备</label>
          <label class="chk"><checkbox value="cpe" :checked="bizTypes.includes('cpe')" color="#1e88e5" />CPE</label>
          <label class="chk"><checkbox value="stock" :checked="bizTypes.includes('stock')" color="#1e88e5" />存量业务</label>
        </checkbox-group>
      </view>
      <view class="field">
        <text class="label">证件号码</text>
        <input v-model="form.idNo" class="input" placeholder="身份证号 / 统一社会信用代码" />
      </view>
      <view class="field">
        <text class="label">证件照片</text>
        <view class="upload" @click="pickLicense">
          <image v-if="licensePath" :src="licensePath" mode="aspectFill" class="preview" />
          <text v-else class="upload-tip">点击上传身份证或营业执照</text>
        </view>
      </view>
      <view class="field">
        <text class="label">备注（选填）</text>
        <textarea v-model="form.remark" class="textarea" placeholder="渠道来源、覆盖能力等" />
      </view>
    </view>

    <button class="btn btn-primary" :disabled="loading" @click="submit">提交申请</button>
    <text class="link" @click="goLogin">已有账号？去登录</text>
    <AppFeedback />
  </view>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import AppFeedback from '@/components/AppFeedback.vue'
import { request, uploadImage } from '@/api/http'
import { REGION_OPTIONS, type BizTypeKey } from '@/data/merchants'
import { showToast } from '@/store/feedback'
import { loginByPhone, goRoleHome } from '@/store/session'

const loading = ref(false)
const licensePath = ref('')
const licenseName = ref('')
const bizTypes = ref<BizTypeKey[]>(['haoka', 'broadband_new_card'])
const regionIdx = ref([0, 0])

const form = reactive({
  phone: '',
  code: '',
  name: '',
  contact: '',
  address: '',
  wechat: '',
  backupPhone: '',
  idNo: '',
  remark: '',
})

const regionLabel = computed(() => {
  const opt = REGION_OPTIONS[regionIdx.value[0]]
  if (!opt) return ''
  const d = opt.districts[regionIdx.value[1]] || opt.districts[0]
  return `${opt.province} ${opt.city} ${d}`
})

function onBiz(e: { detail: { value: string[] } }) {
  bizTypes.value = e.detail.value as BizTypeKey[]
}

function pickRegion() {
  uni.showActionSheet({
    itemList: REGION_OPTIONS.map((o) => `${o.province}${o.city}`),
    success(res) {
      const pi = res.tapIndex
      const districts = REGION_OPTIONS[pi].districts
      uni.showActionSheet({
        itemList: districts,
        success(r2) {
          regionIdx.value = [pi, r2.tapIndex]
        },
      })
    },
  })
}

async function onCode() {
  if (!/^1\d{10}$/.test(form.phone.trim())) {
    showToast('请先填写手机号', { type: 'error' })
    return
  }
  try {
    await request({ url: '/api/mp/auth/sms', method: 'POST', data: { phone: form.phone.trim() } })
  } catch (err) {
    showToast(err instanceof Error ? err.message : '验证码发送失败', { type: 'error' })
    return
  }
  showToast('验证码已发送', { type: 'success', subtitle: '请查收短信' })
}

function pickLicense() {
  uni.chooseImage({
    count: 1,
    success(res) {
      licensePath.value = res.tempFilePaths[0]
      licenseName.value = `license_${Date.now()}.jpg`
    },
  })
}

async function submit() {
  if (!/^1\d{10}$/.test(form.phone.trim())) {
    showToast('请填写正确手机号', { type: 'error' })
    return
  }
  if (!/^\d{4,6}$/.test(form.code.trim())) {
    showToast('请填写验证码', { type: 'error' })
    return
  }
  if (!form.name.trim() || !form.contact.trim()) {
    showToast('请填写门店与联系人', { type: 'error' })
    return
  }
  if (!form.address.trim()) {
    showToast('请填写详细地址', { type: 'error' })
    return
  }
  if (!form.idNo.trim()) {
    showToast('请填写证件号码', { type: 'error' })
    return
  }
  if (!licenseName.value) {
    showToast('请上传证件照片', { type: 'error' })
    return
  }
  if (!bizTypes.value.length) {
    showToast('请选择可接业务', { type: 'error' })
    return
  }
  const opt = REGION_OPTIONS[regionIdx.value[0]]
  const district = opt.districts[regionIdx.value[1]] || opt.districts[0]

  loading.value = true
  try {
    let uploaded = licenseName.value
    if (licensePath.value && !licensePath.value.startsWith('http')) {
      uploaded = await uploadImage(licensePath.value, true)
      licenseName.value = uploaded
    }
    await request({
      url: '/api/mp/merchant/apply',
      method: 'POST',
      data: {
        phone: form.phone.trim(),
        code: form.code.trim(),
        name: form.name.trim(),
        contact: form.contact.trim(),
        province: opt.province,
        city: opt.city,
        district,
        address: form.address.trim(),
        wechat: form.wechat.trim(),
        backupPhone: form.backupPhone.trim(),
        idNo: form.idNo.trim(),
        licenseName: uploaded,
        remark: form.remark.trim(),
        bizTypes: [...bizTypes.value],
      },
    })
  } catch (e) {
    loading.value = false
    showToast(e instanceof Error ? e.message : '提交失败', { type: 'error' })
    return
  }
  const loginErr = await loginByPhone(form.phone.trim(), 'merchant', form.code.trim())
  loading.value = false
  if (loginErr) {
    showToast(loginErr, { type: 'error' })
    return
  }
  showToast('申请已提交', { type: 'success', subtitle: '请等待运营审核', duration: 900 })
  setTimeout(() => goRoleHome('merchant'), 900)
}

function goLogin() {
  uni.reLaunch({ url: '/pages/index/index?role=merchant' })
}
</script>

<style scoped>
.card {
  padding: 24rpx;
  margin-bottom: 20rpx;
}
.h {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #122033;
}
.d {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #6b7a90;
  line-height: 1.45;
}
.sec {
  display: block;
  font-size: 28rpx;
  font-weight: 700;
  color: #122033;
  margin-bottom: 8rpx;
}
.field {
  padding: 18rpx 0;
  border-bottom: 1rpx solid #e8eef5;
}
.field:last-child {
  border-bottom: none;
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
  color: #122033;
}
.picker {
  font-size: 28rpx;
  color: #122033;
}
.code-row {
  display: flex;
  gap: 12rpx;
  align-items: center;
}
.flex {
  flex: 1;
}
.code-btn {
  margin: 0;
  font-size: 24rpx;
  color: #1e88e5;
  background: rgba(30, 136, 229, 0.1);
  border-radius: 12rpx;
  padding: 0 20rpx;
  height: 64rpx;
  line-height: 64rpx;
  font-weight: 600;
}
.chk {
  display: block;
  margin: 10rpx 0;
  font-size: 26rpx;
  color: #122033;
}
.upload {
  height: 200rpx;
  background: #f0f4fa;
  border-radius: 12rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.upload-tip {
  font-size: 24rpx;
  color: #9aa3b2;
}
.preview {
  width: 100%;
  height: 100%;
}
.textarea {
  width: 100%;
  min-height: 120rpx;
  font-size: 28rpx;
}
.btn {
  margin-top: 12rpx;
  height: 92rpx;
  line-height: 92rpx;
  font-size: 32rpx;
}
.link {
  display: block;
  text-align: center;
  margin-top: 24rpx;
  color: #1e88e5;
  font-size: 26rpx;
  font-weight: 600;
}
</style>
