import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { '@': resolve(__dirname, 'src') }
  },
  build: {
    // Output to dist/ — point Snap's staticFileHandler at this directory
    outDir: 'dist',
    emptyOutDir: true,
    // Hashed filenames for cache-busting
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name]-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      }
    }
  },
  // Change this if Snap serves the frontend under a sub-path, e.g. base: '/app/'
  base: '/',
})
