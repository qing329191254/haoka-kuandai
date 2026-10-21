import chinaPca from '@/data/china_pca.json'

export interface RegionNode {
  name: string
  children?: RegionNode[]
}

export interface RegionSelection {
  province: string
  city: string
  district: string
}

function normalize(list: unknown): RegionNode[] {
  if (!Array.isArray(list)) return []
  return list
    .map((item) => {
      if (!item || typeof item !== 'object') return null
      const row = item as { name?: string; children?: unknown }
      const name = String(row.name || '').trim()
      if (!name) return null
      return {
        name,
        children: normalize(row.children),
      } satisfies RegionNode
    })
    .filter((x): x is RegionNode => !!x)
}

/** 全国省市区（本地 JSON，与 App china_pca 同源） */
export const chinaRegionTree: RegionNode[] = normalize(chinaPca)

export function regionLabel(sel: RegionSelection | null | undefined) {
  if (!sel?.province) return ''
  return `${sel.province} ${sel.city} ${sel.district}`.trim()
}

export function findRegionIndexes(
  list: RegionNode[],
  sel?: Partial<RegionSelection> | null,
): [number, number, number] {
  if (!list.length) return [0, 0, 0]
  let p = 0
  let c = 0
  let d = 0
  if (sel?.province) {
    const pi = list.findIndex((x) => x.name === sel.province)
    if (pi >= 0) p = pi
  }
  const cities = list[p]?.children || []
  if (sel?.city) {
    const ci = cities.findIndex((x) => x.name === sel.city)
    if (ci >= 0) c = ci
  }
  const districts = cities[c]?.children || []
  if (sel?.district) {
    const di = districts.findIndex((x) => x.name === sel.district)
    if (di >= 0) d = di
  }
  return [p, c, d]
}

export function selectionFromIndexes(
  list: RegionNode[],
  p: number,
  c: number,
  d: number,
): RegionSelection | null {
  const province = list[p]
  const city = province?.children?.[c]
  const district = city?.children?.[d]
  if (!province || !city || !district) return null
  return {
    province: province.name,
    city: city.name,
    district: district.name,
  }
}
