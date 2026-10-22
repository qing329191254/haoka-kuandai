import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import ElementPlus from 'unplugin-element-plus/vite'

export default defineConfig({
  plugins: [
    vue(),
    AutoImport({
      resolvers: [ElementPlusResolver()],
      dts: false,
    }),
    Components({
      resolvers: [ElementPlusResolver()],
      dts: false,
    }),
    // 给 ElMessage / ElMessageBox / ElLoading 等 API 补按需样式
    ElementPlus({}),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://127.0.0.1:8000',
    },
  },
  build: {
    rollupOptions: {
      output: {
        // 仅拆出 echarts；Element Plus 随页面按需分包
        manualChunks(id) {
          if (
            id.includes('node_modules') &&
            (id.includes('echarts') || id.includes('vue-echarts') || id.includes('zrender'))
          ) {
            return 'echarts'
          }
        },
      },
    },
  },
})
