export interface RegionNode {
  name: string
  children?: RegionNode[]
}

let cache: RegionNode[] | null = null
let loading: Promise<RegionNode[]> | null = null

/** 与 App assets/regions/china_pca.json 同源，供后台商家省市区选择 */
export async function loadChinaRegions(): Promise<RegionNode[]> {
  if (cache) return cache
  if (!loading) {
    loading = fetch('/regions/china_pca.json')
      .then((r) => r.json())
      .then((data: RegionNode[]) => {
        cache = data
        return data
      })
  }
  return loading
}

export function regionPath(province: string, city: string, district: string): string[] {
  return [province, city, district].filter(Boolean)
}
