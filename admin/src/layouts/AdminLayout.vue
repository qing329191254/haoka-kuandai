<template>
  <el-container class="layout">
    <el-aside width="232px" class="aside">
      <div class="brand">
        <img src="/logo.png" alt="派客邦" class="logo" />
        <div class="copy">
          <div class="name">派客邦</div>
          <div class="sub">运营后台</div>
        </div>
      </div>
      <el-menu
        :default-active="active"
        :default-openeds="['biz', 'wh', 'mp', 'app', 'sys']"
        router
        class="side-menu"
        background-color="transparent"
        text-color="#c5d4e8"
        active-text-color="#ffffff"
      >
        <el-menu-item v-if="can('dashboard:view')" index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <span>运营概览</span>
        </el-menu-item>
        <el-menu-item v-if="can('orders:view')" index="/orders">
          <el-icon><List /></el-icon>
          <span>订单中心</span>
        </el-menu-item>

        <el-sub-menu v-if="can('products:view') || can('warehouse:view') || can('stock:view')" index="wh">
          <template #title>
            <el-icon><Box /></el-icon>
            <span>产品与仓库</span>
          </template>
          <el-menu-item v-if="can('products:view')" index="/products">商品套餐</el-menu-item>
          <el-menu-item v-if="can('products:view')" index="/stock-types">存量业务类型</el-menu-item>
          <el-menu-item v-if="can('warehouse:view')" index="/warehouse">号卡仓库</el-menu-item>
          <el-menu-item v-if="can('stock:view')" index="/stock">号卡出入库</el-menu-item>
        </el-sub-menu>

        <el-sub-menu v-if="can('merchants:view') || can('technicians:view')" index="mp">
          <template #title>
            <el-icon><ChatDotRound /></el-icon>
            <span>小程序端</span>
          </template>
          <el-menu-item v-if="can('merchants:view')" index="/merchant-apps">商家入驻申请</el-menu-item>
          <el-menu-item v-if="can('merchants:view')" index="/merchants">本地商家</el-menu-item>
          <el-menu-item v-if="can('technicians:view')" index="/technicians">上门师傅</el-menu-item>
        </el-sub-menu>

        <el-sub-menu
          v-if="canAny('agents:view', 'users:view', 'service:view', 'feedback:view', 'content:view')"
          index="app"
        >
          <template #title>
            <el-icon><Iphone /></el-icon>
            <span>App 端</span>
            <span v-if="csUnread" class="cs-unread-dot" />
          </template>
          <el-menu-item v-if="can('agents:view')" index="/agent-apps">代理入驻申请</el-menu-item>
          <el-menu-item v-if="can('agents:view')" index="/deposit-rules">押金规则</el-menu-item>
          <el-menu-item v-if="can('agents:view')" index="/agents">代理商</el-menu-item>
          <el-menu-item v-if="can('users:view')" index="/users">App 用户</el-menu-item>
          <el-menu-item v-if="can('service:view')" index="/service">客服配置</el-menu-item>
          <el-menu-item v-if="can('service:view')" index="/app-version">版本更新</el-menu-item>
          <el-menu-item v-if="can('feedback:view')" index="/cs-chat">
            <span class="menu-label">
              在线客服
              <span v-if="csUnread" class="cs-unread-num">{{ csUnread > 99 ? '99+' : csUnread }}</span>
            </span>
          </el-menu-item>
          <el-menu-item v-if="can('feedback:view')" index="/feedback">意见反馈</el-menu-item>
          <el-menu-item v-if="can('content:view')" index="/content">协议与帮助</el-menu-item>
        </el-sub-menu>

        <el-menu-item v-if="can('flows:view')" index="/flows">
          <el-icon><Guide /></el-icon>
          <span>业务流转</span>
        </el-menu-item>

        <el-sub-menu v-if="can('accounts:view') || can('roles:view')" index="sys">
          <template #title>
            <el-icon><Lock /></el-icon>
            <span>账号权限</span>
          </template>
          <el-menu-item v-if="can('accounts:view')" index="/accounts">后台账号</el-menu-item>
          <el-menu-item v-if="can('roles:view')" index="/roles">角色权限</el-menu-item>
        </el-sub-menu>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <div class="title-wrap">
          <span class="page-title">{{ route.meta.title || '运营后台' }}</span>
          <span class="hint">按角色授权访问</span>
        </div>
        <div class="right">
          <el-tag size="small" effect="dark" class="role-tag">{{ role?.name || '未分配' }}</el-tag>
          <div class="avatar">{{ (current?.name || '管').slice(0, 1) }}</div>
          <span class="user">{{ current?.name }}</span>
          <el-button class="logout" @click="onLogout">退出</el-button>
        </div>
      </el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'
import { usePermission } from '@/composables/usePermission'
import { useAdminStore } from '@/stores/admin'
import { useCsChatStore } from '@/stores/csChat'

const route = useRoute()
const router = useRouter()
const { can, auth, role, current } = usePermission()
const admin = useAdminStore()
const csChat = useCsChatStore()
const { unreadTotal: csUnread } = storeToRefs(csChat)

onMounted(() => {
  admin.hydrate()
  if (can('feedback:view')) csChat.start(true)
})

onUnmounted(() => {
  csChat.stop()
})

function canAny(...perms: string[]) {
  return auth.canAny(...perms)
}

const active = computed(() => {
  if (route.path.startsWith('/orders')) return '/orders'
  return route.path
})

function onLogout() {
  auth.logout()
  router.push('/login')
}
</script>

<style scoped lang="scss">
.layout {
  height: 100%;
}
.aside {
  background:
    radial-gradient(420px 220px at 0% 0%, rgba(61, 155, 232, 0.22), transparent 60%),
    linear-gradient(180deg, #0a1d36 0%, #071628 42%, #0b2444 100%);
  box-shadow: 8px 0 32px rgba(7, 22, 40, 0.18);
  /* 只占位、不强制显示：无溢出时隐藏滑块，展开溢出时出现在预留槽内，避免宽度抖动 */
  overflow-x: hidden;
  overflow-y: auto;
  scrollbar-gutter: stable;
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.18) transparent;
  overscroll-behavior: contain;
  &::-webkit-scrollbar {
    width: 6px;
  }
  &::-webkit-scrollbar-track {
    background: transparent;
  }
  &::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.16);
    border-radius: 999px;
    border: 2px solid transparent;
    background-clip: padding-box;
  }
  &::-webkit-scrollbar-thumb:hover {
    background: rgba(61, 155, 232, 0.55);
  }
  .brand {
    height: 76px;
    padding: 16px 16px 12px;
    display: flex;
    align-items: center;
    gap: 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    .logo {
      width: 44px;
      height: 44px;
      object-fit: contain;
      filter: drop-shadow(0 6px 12px rgba(26, 115, 232, 0.35));
    }
    .name {
      font-weight: 760;
      letter-spacing: 3px;
      font-size: 18px;
      color: #fff;
    }
    .sub {
      margin-top: 2px;
      font-size: 12px;
      color: #8aa4c4;
    }
  }
  .side-menu {
    border-right: none;
    padding: 10px 8px 24px;
    overflow-x: hidden;
  }
  :deep(.el-menu),
  :deep(.el-sub-menu) {
    min-width: 0 !important;
  }
  :deep(.el-menu-item),
  :deep(.el-sub-menu__title) {
    border-radius: 10px;
    margin: 2px 0;
    height: 44px;
    min-width: 0 !important;
    -webkit-font-smoothing: antialiased;
  }
  :deep(.el-sub-menu .el-menu) {
    overflow: hidden;
    background: transparent !important;
  }
  :deep(.el-collapse-transition-enter-active),
  :deep(.el-collapse-transition-leave-active) {
    overflow: hidden !important;
  }
  :deep(.el-menu-item.is-active) {
    background: linear-gradient(90deg, rgba(26, 115, 232, 0.92), rgba(61, 155, 232, 0.55)) !important;
    box-shadow: 0 8px 16px rgba(26, 115, 232, 0.22);
  }
  :deep(.el-menu-item:hover:not(.is-active)),
  :deep(.el-sub-menu__title:hover) {
    background: rgba(255, 255, 255, 0.06) !important;
  }
  :deep(.el-menu-item.is-active:hover) {
    background: linear-gradient(90deg, rgba(59, 143, 243, 1), rgba(26, 115, 232, 0.75)) !important;
  }
  :deep(.el-sub-menu .el-menu-item) {
    padding-left: 52px !important;
  }
  .menu-label {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
  .cs-unread-num {
    min-width: 18px;
    height: 18px;
    padding: 0 5px;
    border-radius: 9px;
    background: #f56c6c;
    color: #fff;
    font-size: 11px;
    font-weight: 700;
    line-height: 18px;
    text-align: center;
    box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.25);
  }
  .cs-unread-dot {
    width: 8px;
    height: 8px;
    margin-left: 8px;
    border-radius: 50%;
    background: #f56c6c;
    box-shadow: 0 0 0 2px rgba(245, 108, 108, 0.25);
  }
}
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 64px;
  background: rgba(255, 255, 255, 0.78);
  border-bottom: 1px solid rgba(226, 234, 244, 0.9);
  box-shadow: 0 8px 24px rgba(15, 40, 80, 0.04);
  backdrop-filter: blur(14px);
  .title-wrap {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .page-title {
    font-size: 17px;
    font-weight: 700;
    letter-spacing: 0.3px;
  }
  .hint {
    font-size: 12px;
    color: #8a97a8;
  }
  .right {
    display: flex;
    gap: 10px;
    align-items: center;
  }
  .role-tag {
    background: linear-gradient(180deg, #f6d15a, #e8b923) !important;
    border: none;
    color: #5a4300;
    font-weight: 650;
  }
  .avatar {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    color: #fff;
    font-size: 13px;
    font-weight: 700;
    background: linear-gradient(180deg, #3d9be8, #1a73e8);
    box-shadow: 0 6px 12px rgba(26, 115, 232, 0.28);
  }
  .user {
    color: #3d4a5c;
    font-size: 13px;
    font-weight: 600;
  }
  .logout {
    margin-left: 4px;
  }
}
.main {
  padding: 22px 24px 28px;
}
</style>
