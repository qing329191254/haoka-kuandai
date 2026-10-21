import { createSSRApp } from 'vue'
import App from './App.vue'
import { hideMpHomeButton } from './utils/hideHomeButton'
import {
  enableMpShareMenu,
  getMpShareAppMessage,
  getMpShareTimeline,
} from './utils/mpShare'

export function createApp() {
  const app = createSSRApp(App)
  // 页面级：隐藏主页钮 + 开启分享菜单；分享回调供右上角「转发/朋友圈」使用
  app.mixin({
    onShow() {
      hideMpHomeButton()
      setTimeout(hideMpHomeButton, 50)
      enableMpShareMenu()
    },
    onShareAppMessage() {
      return getMpShareAppMessage()
    },
    onShareTimeline() {
      return getMpShareTimeline()
    },
  })
  return {
    app,
  }
}
