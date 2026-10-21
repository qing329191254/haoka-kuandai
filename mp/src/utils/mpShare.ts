/** 小程序默认分享内容（发送给朋友 / 朋友圈） */
export function getMpShareAppMessage() {
  return {
    title: '派客邦 · 本地商家与上门师傅工作台',
    path: '/pages/index/index',
    imageUrl: '/static/splash_logo.png',
  }
}

export function getMpShareTimeline() {
  return {
    title: '派客邦 · 本地商家与上门师傅工作台',
    query: '',
    imageUrl: '/static/splash_logo.png',
  }
}

export function enableMpShareMenu() {
  try {
    uni.showShareMenu({
      withShareTicket: true,
      menus: ['shareAppMessage', 'shareTimeline'],
    })
  } catch {
    /* 非微信端忽略 */
  }
}
