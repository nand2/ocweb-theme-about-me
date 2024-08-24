import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    lib: {
      entry: './src/components/AdminPanel.vue',
      name: 'themeAboutMeAdmin0',
      formats: ['umd'],
      fileName: (format) => `admin.${format}.js`,
    },
    rollupOptions: {
      external: ['vue', '@tanstack/vue-query', '@wagmi/vue'],
      output: {
        assetFileNames: "admin.[ext]",
        globals: {
          vue: 'Vue',
          '@tanstack/vue-query': 'TanstackVueQuery',
          '@wagmi/vue': 'WagmiVue',
        },
      },
    },
  },
})
