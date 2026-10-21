<template>
  <view class="page page-shell">
    <view class="hero-panel">
      <text class="kicker">派客邦</text>
      <text class="hero-title">本地商家 · 上门师傅</text>
      <text class="hero-desc">给已入驻商家和所属师傅使用。本页无需登录，真实订单在登录后查看。</text>
    </view>

    <text class="section">谁可以使用</text>
    <view class="card surface">
      <view class="who">
        <view class="badge">商</view>
        <view class="who-body">
          <text class="who-t">商家</text>
          <text class="who-d">接单、办理、派单，以及管理本店师傅。需先入驻，并通过运营审核。</text>
        </view>
      </view>
      <view class="who line">
        <view class="badge tech">师</view>
        <view class="who-body">
          <text class="who-t">上门师傅</text>
          <text class="who-d">查看上门任务，拍照确认交付。无法完成时退回商家。由所属商家添加，不单独注册。</text>
        </view>
      </view>
    </view>

    <text class="section">办理怎么走</text>
    <view class="card surface steps">
      <view v-for="(item, i) in steps" :key="item.title" class="step">
        <text class="step-no">{{ i + 1 }}</text>
        <view class="step-body">
          <text class="who-t">{{ item.title }}</text>
          <text class="who-d">{{ item.desc }}</text>
        </view>
      </view>
    </view>

    <text class="section">订单示例</text>
    <view class="card surface sample">
      <view class="sample-top">
        <text class="biz">融合宽带</text>
        <text class="pill">示例</text>
      </view>
      <text class="who-t name">300M 融合套餐</text>
      <text class="meta">张* · 138****1206</text>
      <text class="meta">某市某区示例路 8 号</text>
      <text class="note">客户姓名、手机号和地址只对已登录的对应商家或师傅展示。</text>
    </view>

    <button class="btn btn-primary go" @click="goLogin('merchant')">商家登录</button>
    <button class="go tech" @click="goLogin('technician')">师傅登录</button>
    <text class="apply" @click="goApply">商家入驻申请</text>
  </view>
</template>

<script setup lang="ts">
const steps = [
  { title: '商家提交入驻', desc: '填写门店、服务地区和可接业务，等待运营审核。' },
  { title: '审核通过后登录', desc: '使用申请手机号登录，处理新录入的订单。' },
  { title: '办理或派单上门', desc: '能线上办结的直接办结；需要上门的派给本店师傅。' },
  { title: '师傅上门确认', desc: '师傅拍照交付。无法完成则退回，由商家继续跟进或重新派单。' },
]

function goApply() {
  uni.navigateTo({ url: '/pages/merchant/apply' })
}

function goLogin(role: 'merchant' | 'technician') {
  uni.reLaunch({ url: `/pages/index/index?role=${role}` })
}
</script>

<style scoped>
.kicker,
.hero-title,
.hero-desc {
  position: relative;
  z-index: 1;
  display: block;
}
.kicker {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.72);
  letter-spacing: 2rpx;
}
.hero-title {
  margin-top: 10rpx;
  font-size: 40rpx;
  font-weight: 800;
  color: #fff;
}
.hero-desc {
  margin-top: 16rpx;
  font-size: 26rpx;
  line-height: 1.55;
  color: rgba(255, 255, 255, 0.86);
}
.section {
  display: block;
  margin: 8rpx 4rpx 16rpx;
  font-size: 26rpx;
  font-weight: 700;
  color: #5a6b80;
}
.card {
  padding: 8rpx 28rpx;
  margin-bottom: 28rpx;
}
.who,
.step {
  display: flex;
  gap: 20rpx;
  padding: 24rpx 0;
}
.who.line {
  border-top: 1rpx solid #e8eef5;
}
.badge,
.step-no {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  background: linear-gradient(145deg, #42a5f5, #1e88e5);
  color: #fff;
  font-size: 28rpx;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.badge.tech {
  background: linear-gradient(145deg, #26a69a, #00897b);
}
.step-no {
  width: 44rpx;
  height: 44rpx;
  border-radius: 50%;
  font-size: 24rpx;
  margin-top: 4rpx;
}
.steps {
  padding-top: 12rpx;
  padding-bottom: 12rpx;
}
.who-body,
.step-body {
  flex: 1;
  width: 0;
  min-width: 0;
}
.who-t {
  display: block;
  font-size: 30rpx;
  font-weight: 700;
  color: #122033;
}
.who-d,
.meta,
.note {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.5;
  color: #6b7a90;
}
.sample {
  padding: 28rpx;
}
.sample-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.biz {
  font-size: 24rpx;
  font-weight: 700;
  color: #1e88e5;
}
.pill {
  font-size: 22rpx;
  color: #1e88e5;
  background: rgba(30, 136, 229, 0.1);
  border-radius: 999rpx;
  padding: 6rpx 16rpx;
}
.name {
  margin-top: 16rpx;
}
.note {
  margin-top: 16rpx;
  padding-top: 16rpx;
  border-top: 1rpx solid #e8eef5;
}
.go {
  margin: 0;
  height: 88rpx;
  line-height: 88rpx;
  font-size: 30rpx;
  font-weight: 600;
  border-radius: 18rpx;
}
.go.tech {
  margin-top: 16rpx;
  color: #fff;
  background: linear-gradient(135deg, #26a69a, #00897b);
}
.go.tech::after,
.go::after {
  border: none;
}
.apply {
  display: block;
  margin-top: 22rpx;
  text-align: center;
  font-size: 26rpx;
  color: #1e88e5;
  font-weight: 600;
}
</style>
