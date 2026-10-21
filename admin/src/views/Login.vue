<template>
  <div class="login">
    <div class="bg" aria-hidden="true">
      <div class="wash" />
      <div class="mesh" />
      <div class="grid" />
      <div class="orb orb-a" />
      <div class="orb orb-b" />
      <div class="orb orb-c" />
      <svg class="net" viewBox="0 0 1440 900" preserveAspectRatio="xMidYMid slice">
        <defs>
          <linearGradient id="lg" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="rgba(255,255,255,0)" />
            <stop offset="45%" stop-color="rgba(186,230,253,0.45)" />
            <stop offset="100%" stop-color="rgba(255,255,255,0)" />
          </linearGradient>
        </defs>
        <g stroke="url(#lg)" stroke-width="1.15" fill="none">
          <path d="M60 680 C240 520, 380 580, 560 400 S880 180, 1280 260" />
          <path d="M40 260 C220 320, 420 120, 680 220 S1040 420, 1380 300" />
          <path d="M120 820 C360 700, 540 760, 780 600 S1100 520, 1400 560" />
        </g>
        <g fill="rgba(186,230,253,0.55)">
          <circle cx="560" cy="400" r="3.5" />
          <circle cx="680" cy="220" r="2.8" />
          <circle cx="780" cy="600" r="3.2" />
          <circle cx="1280" cy="260" r="2.6" />
          <circle cx="240" cy="520" r="2.4" />
        </g>
      </svg>
    </div>

    <div class="shell">
      <aside class="brand">
        <img src="/logo.png" alt="" class="mark" />
        <h1>派客邦</h1>
        <p class="tagline">号卡 · 宽带业务运营中枢</p>
        <ul class="points">
          <li>代理入驻审批与档案管理</li>
          <li>本地商家 / 师傅协同履约</li>
          <li>全量订单流转一目了然</li>
        </ul>
      </aside>

      <div class="divider" aria-hidden="true" />

      <section class="form-side">
        <h2>欢迎登录</h2>
        <p class="hint">请使用分配的账号进入运营工作台</p>
        <el-form class="form" @submit.prevent="onSubmit">
          <el-form-item>
            <el-input v-model="form.username" placeholder="请输入账号" prefix-icon="User" size="large" />
          </el-form-item>
          <el-form-item>
            <el-input
              v-model="form.password"
              type="password"
              placeholder="请输入密码"
              prefix-icon="Lock"
              show-password
              size="large"
            />
          </el-form-item>
          <el-button type="primary" size="large" class="submit" native-type="submit">登 录</el-button>
        </el-form>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()
const form = reactive({ username: 'admin', password: '123456' })

async function onSubmit() {
  const res = await auth.login(form.username, form.password)
  if (!res.ok) {
    ElMessage.error(res.message)
    return
  }
  ElMessage.success(res.message)
  router.push(auth.firstAllowedPath())
}
</script>

<style scoped lang="scss">
.login {
  min-height: 100%;
  position: relative;
  overflow: hidden;
  display: grid;
  place-items: center;
  padding: 40px 24px;
  background: #0a1f3a;
}

.bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}
.wash {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(ellipse 90% 70% at 18% 18%, rgba(56, 156, 232, 0.5), transparent 58%),
    radial-gradient(ellipse 70% 55% at 88% 14%, rgba(125, 211, 252, 0.26), transparent 52%),
    radial-gradient(ellipse 80% 60% at 78% 88%, rgba(14, 116, 180, 0.38), transparent 55%),
    linear-gradient(155deg, #061526 0%, #0c2d52 42%, #134e82 72%, #0b2744 100%);
}
.mesh {
  position: absolute;
  inset: -15%;
  background:
    conic-gradient(from 210deg at 30% 40%, rgba(56, 189, 248, 0.1), transparent 28%, rgba(30, 136, 229, 0.08), transparent 60%),
    conic-gradient(from 40deg at 70% 65%, rgba(186, 230, 253, 0.08), transparent 35%, rgba(14, 165, 233, 0.06), transparent 70%);
  animation: mesh-drift 22s ease-in-out infinite alternate;
}
.grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(186, 230, 253, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(186, 230, 253, 0.08) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 85% 75% at 50% 45%, #000 20%, transparent 80%);
  opacity: 0.6;
}
.orb {
  position: absolute;
  border-radius: 50%;
}
.orb-a {
  width: 380px;
  height: 380px;
  right: 6%;
  top: 8%;
  background: radial-gradient(circle, rgba(125, 211, 252, 0.34), transparent 68%);
  animation: float-a 16s ease-in-out infinite;
}
.orb-b {
  width: 300px;
  height: 300px;
  left: 4%;
  bottom: 6%;
  background: radial-gradient(circle, rgba(30, 136, 229, 0.32), transparent 70%);
  animation: float-b 18s ease-in-out infinite;
}
.orb-c {
  width: 170px;
  height: 170px;
  left: 46%;
  top: 16%;
  background: radial-gradient(circle, rgba(253, 224, 71, 0.14), transparent 70%);
  animation: float-c 12s ease-in-out infinite;
}
.net {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0.75;
}

/* 一张整卡：品牌 + 登录，避免整页左右硬切 */
.shell {
  position: relative;
  z-index: 1;
  width: min(920px, 100%);
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: stretch;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(186, 230, 253, 0.28);
  backdrop-filter: blur(22px);
  box-shadow:
    0 28px 70px rgba(3, 18, 36, 0.35),
    inset 0 1px 0 rgba(255, 255, 255, 0.16);
  overflow: hidden;
  animation: rise 0.6s cubic-bezier(0.22, 1, 0.36, 1) both;
}

.brand {
  padding: 48px 40px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  color: #e8f3ff;
}
.mark {
  width: 76px;
  height: 76px;
  object-fit: contain;
  margin-bottom: 20px;
  filter: drop-shadow(0 12px 24px rgba(56, 189, 248, 0.35));
}
.brand h1 {
  margin: 0;
  font-size: 44px;
  font-weight: 800;
  letter-spacing: 6px;
  padding-left: 6px;
  color: #fff;
  line-height: 1.15;
}
.tagline {
  margin: 14px 0 0;
  font-size: 16px;
  color: #bae6fd;
  letter-spacing: 1.5px;
}
.points {
  margin: 32px 0 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}
.points li {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: rgba(226, 240, 255, 0.9);
}
.points li::before {
  content: '';
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #38bdf8;
  box-shadow: 0 0 0 3px rgba(56, 189, 248, 0.22);
}

.divider {
  width: 1px;
  margin: 36px 0;
  background: linear-gradient(
    180deg,
    transparent,
    rgba(186, 230, 253, 0.35) 20%,
    rgba(186, 230, 253, 0.35) 80%,
    transparent
  );
}

.form-side {
  padding: 48px 44px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.form-side h2 {
  margin: 0;
  font-size: 26px;
  font-weight: 700;
  color: #f0f9ff;
}
.hint {
  margin: 10px 0 28px;
  font-size: 13px;
  color: rgba(186, 230, 253, 0.82);
}
.form {
  :deep(.el-form-item) {
    margin-bottom: 18px;
  }
  :deep(.el-input__wrapper) {
    background: rgba(255, 255, 255, 0.9);
    box-shadow: 0 0 0 1px rgba(186, 230, 253, 0.28) inset;
  }
  :deep(.el-input__wrapper:hover),
  :deep(.el-input__wrapper.is-focus) {
    background: #fff;
  }
}
.submit {
  width: 100%;
  margin-top: 6px;
  letter-spacing: 4px;
}

@keyframes mesh-drift {
  from {
    transform: translate3d(-2%, -1%, 0) rotate(0deg);
  }
  to {
    transform: translate3d(3%, 2%, 0) rotate(4deg);
  }
}
@keyframes float-a {
  0%,
  100% {
    transform: translate(0, 0);
  }
  50% {
    transform: translate(-16px, 18px);
  }
}
@keyframes float-b {
  0%,
  100% {
    transform: translate(0, 0);
  }
  50% {
    transform: translate(14px, -12px);
  }
}
@keyframes float-c {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(-8px, 10px) scale(1.06);
  }
}
@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (max-width: 820px) {
  .shell {
    grid-template-columns: 1fr;
    max-width: 420px;
  }
  .divider {
    width: auto;
    height: 1px;
    margin: 0 32px;
    background: linear-gradient(
      90deg,
      transparent,
      rgba(186, 230, 253, 0.35) 20%,
      rgba(186, 230, 253, 0.35) 80%,
      transparent
    );
  }
  .brand {
    padding: 36px 32px 20px;
  }
  .brand h1 {
    font-size: 36px;
  }
  .points {
    display: none;
  }
  .form-side {
    padding: 24px 32px 36px;
  }
}
</style>
