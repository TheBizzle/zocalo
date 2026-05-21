import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import { resolve } from "path"

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { "@": resolve(__dirname, "src") }
  },
  build: {
    outDir: "dist"
  , emptyOutDir: true
  , rollupOptions: { // Hashed filenames for cache-busting
      output: {
        entryFileNames: "assets/[name]-[hash].js"
      , chunkFileNames: "assets/[name]-[hash].js"
      , assetFileNames: "assets/[name]-[hash][extname]"
      }
    }
  },
  base: "/",
})
