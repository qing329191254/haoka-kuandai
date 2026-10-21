const TOKEN_KEY = 'haoka_mp_token'

export const API_BASE = import.meta.env.VITE_API_BASE || 'https://www.lcnh-platform.cn'

export function getToken() {
  return String(uni.getStorageSync(TOKEN_KEY) || '')
}

export function setToken(token: string) {
  uni.setStorageSync(TOKEN_KEY, token)
}

export function clearToken() {
  uni.removeStorageSync(TOKEN_KEY)
}

function detailOf(data: unknown, fallback: string) {
  if (data && typeof data === 'object' && 'detail' in data) {
    const d = (data as { detail: unknown }).detail
    if (typeof d === 'string') return d
  }
  return fallback
}

export function request<T>(opts: { url: string; method?: 'GET' | 'POST' | 'PUT' | 'DELETE'; data?: unknown }): Promise<T> {
  return new Promise((resolve, reject) => {
    const token = getToken()
    uni.request({
      url: `${API_BASE}${opts.url}`,
      method: opts.method || 'GET',
      data: opts.data as string | AnyObject | ArrayBuffer | undefined,
      header: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      success(res) {
        if ((res.statusCode || 0) === 401) {
          clearToken()
          uni.removeStorageSync('haoka_mp_session')
          if (!opts.url.includes('/auth/login')) {
            uni.reLaunch({ url: '/pages/index/index' })
          }
          reject(new Error('登录已过期，请重新登录'))
          return
        }
        if ((res.statusCode || 0) >= 400) {
          reject(new Error(detailOf(res.data, '请求失败')))
          return
        }
        resolve(res.data as T)
      },
      fail() {
        reject(new Error('网络异常，请稍后重试'))
      },
    })
  })
}

export function uploadImage(filePath: string, apply = false): Promise<string> {
  return new Promise((resolve, reject) => {
    const token = getToken()
    uni.uploadFile({
      url: `${API_BASE}${apply ? '/api/uploads/apply-images' : '/api/uploads/images'}`,
      filePath,
      name: 'file',
      header: !apply && token ? { Authorization: `Bearer ${token}` } : {},
      success(res) {
        let data: unknown = res.data
        try {
          data = JSON.parse(res.data)
        } catch {
          /* 服务端异常响应可能不是 JSON */
        }
        if ((res.statusCode || 0) === 401) {
          clearToken()
          uni.removeStorageSync('haoka_mp_session')
          reject(new Error('登录已过期，请重新登录'))
          return
        }
        if ((res.statusCode || 0) >= 400) {
          reject(new Error(detailOf(data, '图片上传失败')))
          return
        }
        const url = data && typeof data === 'object' && 'url' in data ? String((data as { url: unknown }).url || '') : ''
        if (!url) {
          reject(new Error('图片上传结果无效'))
          return
        }
        resolve(url)
      },
      fail() {
        reject(new Error('图片上传失败，请检查网络后重试'))
      },
    })
  })
}
