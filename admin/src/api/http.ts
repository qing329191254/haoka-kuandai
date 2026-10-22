import axios, { AxiosError } from 'axios'

const TOKEN_KEY = 'admin_token'

export const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || '',
  timeout: 15000,
})

http.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

http.interceptors.response.use(
  (res) => res,
  (err: AxiosError<{ detail?: string | { msg: string }[] }>) => {
    if (err.response?.status === 401) {
      clearToken()
      localStorage.removeItem('admin_session')
      if (!location.pathname.includes('/login')) location.href = '/login'
    }
    const d = err.response?.data?.detail
    const msg = typeof d === 'string' ? d : err.message || '请求失败'
    return Promise.reject(new Error(msg))
  },
)

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token)
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
}

/** 客服实时通道：管理端用 SSE（HTTPS），避开现网 WSS 下行丢帧 */
export function csEventsUrl() {
  const token = encodeURIComponent(getToken())
  const base = (import.meta.env.VITE_API_BASE || '').replace(/\/$/, '')
  if (base) {
    const u = new URL(base)
    u.pathname = '/api/admin/cs/events'
    u.search = `token=${token}`
    return u.toString()
  }
  return `${location.origin}/api/admin/cs/events?token=${token}`
}

export async function get<T>(url: string, params?: object) {
  const { data } = await http.get<T>(url, { params })
  return data
}

export async function post<T>(url: string, body?: object) {
  const { data } = await http.post<T>(url, body)
  return data
}

export async function put<T>(url: string, body?: object) {
  const { data } = await http.put<T>(url, body)
  return data
}

export async function del<T>(url: string) {
  const { data } = await http.delete<T>(url)
  return data
}
