import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',  // Bind to all interfaces (fixes IPv4/IPv6 mismatch on Windows)
    port: 5173,
    strictPort: false,  // Try next port if 5173 is busy
  }
})
