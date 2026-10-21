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

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
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
