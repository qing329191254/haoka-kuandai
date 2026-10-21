import { ElLoading } from 'element-plus'

type LoadingHandle = { close: () => void; setText: (text: string) => void }

let instance: LoadingHandle | null = null
let depth = 0
/** 同步锁：挡住 Loading 挂上前的同帧连点 */
let actionLocked = false

export function showLoading(text = '加载中…') {
  depth += 1
  if (instance) {
    instance.setText(text)
    return
  }
  instance = ElLoading.service({
    lock: true,
    text,
    background: 'rgba(7, 22, 40, 0.45)',
    customClass: 'app-global-loading',
  })
}

export function hideLoading() {
  depth = Math.max(0, depth - 1)
  if (depth > 0 || !instance) return
  instance.close()
  instance = null
}

export async function withLoading<T>(fn: () => Promise<T>, text = '加载中…'): Promise<T> {
  if (actionLocked) {
    return new Promise<T>(() => {})
  }
  actionLocked = true
  showLoading(text)
  try {
    return await fn()
  } finally {
    hideLoading()
    actionLocked = false
  }
}
