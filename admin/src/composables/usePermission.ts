import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'

export function usePermission() {
  const auth = useAuthStore()
  const can = (perm: string) => auth.hasPermission(perm)
  const isAdmin = computed(() => auth.hasPermission('*'))
  return { auth, can, isAdmin, role: computed(() => auth.role), current: computed(() => auth.current) }
}
