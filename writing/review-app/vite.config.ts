import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"
import { viteSingleFile } from "vite-plugin-singlefile"

// Builds one self-contained HTML file so the review page opens straight from disk.
// The manuscript content is loaded at runtime from ../manuscript2_journal_versions.js.
export default defineConfig({
  base: "./",
  publicDir: false,
  plugins: [react(), tailwindcss(), viteSingleFile()],
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "./src"),
    },
  },
})
