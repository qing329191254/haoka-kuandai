/** 隐藏微信「返回主页」按钮（reLaunch 到非首页时会强制出现，配置项挡不住） */
export function hideMpHomeButton() {
  const run = () => {
    try {
      uni.hideHomeButton({})
    } catch {
      /* 非微信端或不支持时忽略 */
    }
  }
  run()
  setTimeout(run, 50)
  setTimeout(run, 200)
}
