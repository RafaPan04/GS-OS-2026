import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Em desenvolvimento local (npm run dev), /api vai para uma API em localhost:8081.
// Em produção quem faz esse papel é o nginx do nó "app".
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: { '/api': 'http://localhost:8081' }
  }
})
