import { reactive } from 'vue'

export type ToastType = 'success' | 'error' | 'info'
export type ConfirmTone = 'primary' | 'warn'

interface ToastState {
  visible: boolean
  title: string
  subtitle: string
  type: ToastType
}

interface ConfirmState {
  visible: boolean
  title: string
  content: string
  confirmText: string
  cancelText: string
  tone: ConfirmTone
  icon: string
  resolve: ((ok: boolean) => void) | null
}

const toast: ToastState = reactive({
  visible: false,
  title: '',
  subtitle: '',
  type: 'info',
})

const confirm: ConfirmState = reactive({
  visible: false,
  title: '',
  content: '',
  confirmText: '确定',
  cancelText: '取消',
  tone: 'primary',
  icon: '',
  resolve: null,
})

let toastTimer: ReturnType<typeof setTimeout> | null = null

export function feedbackState() {
  return { toast, confirm }
}

export function showToast(
  title: string,
  opts?: { type?: ToastType; subtitle?: string; duration?: number },
) {
  if (toastTimer) {
    clearTimeout(toastTimer)
    toastTimer = null
  }
  toast.title = title
  toast.subtitle = opts?.subtitle || ''
  toast.type = opts?.type || 'info'
  toast.visible = true
  const duration = opts?.duration ?? (opts?.type === 'success' ? 1400 : 1800)
  toastTimer = setTimeout(() => {
    toast.visible = false
    toastTimer = null
  }, duration)
}

export function hideToast() {
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = null
  toast.visible = false
}

export function showConfirm(opts: {
  title: string
  content?: string
  confirmText?: string
  cancelText?: string
  tone?: ConfirmTone
  icon?: string
}): Promise<boolean> {
  return new Promise((resolve) => {
    if (confirm.resolve) confirm.resolve(false)
    confirm.title = opts.title
    confirm.content = opts.content || ''
    confirm.confirmText = opts.confirmText || '确定'
    confirm.cancelText = opts.cancelText || '取消'
    confirm.tone = opts.tone || 'primary'
    confirm.icon = opts.icon || (opts.tone === 'warn' ? '!' : '?')
    confirm.resolve = resolve
    confirm.visible = true
  })
}

export function resolveConfirm(ok: boolean) {
  confirm.visible = false
  const r = confirm.resolve
  confirm.resolve = null
  r?.(ok)
}
