<script setup lang="ts">
import { onLaunch, onShow } from '@dcloudio/uni-app'
import { hideMpHomeButton } from '@/utils/hideHomeButton'

onLaunch(() => {})

onShow(() => {
  hideMpHomeButton()
})
</script>

<style>
@import './styles/theme.css';
</style>
