import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// In development the API runs on its own port; the proxy avoids CORS.
export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': 'http://localhost:__PORT__',
      '/healthz': 'http://localhost:__PORT__',
    },
  },
})
