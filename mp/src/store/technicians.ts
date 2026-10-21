import { request } from '@/api/http'
import type { MpTechnician } from '@/data/technicians'

export async function fetchTechnicians(): Promise<MpTechnician[]> {
  const data = await request<{ items: MpTechnician[] }>({ url: '/api/mp/technicians' })
  return data.items || []
}

export async function saveTechnician(row: Partial<MpTechnician> & { name: string; phone: string }) {
  const body = {
    name: row.name,
    phone: row.phone,
    province: row.province || '',
    city: row.city || '',
    district: row.district || '',
    skills: row.skills || [],
    status: row.status || 'active',
  }
  if (row.id) {
    await request({ url: `/api/mp/technicians/${row.id}`, method: 'PUT', data: body })
  } else {
    await request({ url: '/api/mp/technicians', method: 'POST', data: body })
  }
}

export async function removeTechnician(id: string) {
  await request({ url: `/api/mp/technicians/${id}`, method: 'DELETE' })
}
