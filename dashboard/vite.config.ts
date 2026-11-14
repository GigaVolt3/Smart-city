import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const backend = env.VITE_BACKEND_URL || "http://127.0.0.1:8000";

  return {
    plugins: [react()],
    server: {
      port: 5173,
      host: "127.0.0.1",
      proxy: {
        "/api": { target: backend, changeOrigin: true },
        "/uploads": { target: backend, changeOrigin: true },
      },
    },
    preview: {
      port: 4173,
      host: "127.0.0.1",
      proxy: {
        "/api": { target: backend, changeOrigin: true },
        "/uploads": { target: backend, changeOrigin: true },
      },
    },
    build: {
      outDir: "dist",
      sourcemap: false,
      chunkSizeWarningLimit: 900,
      rollupOptions: {
        output: {
          manualChunks: {
            react: ["react", "react-dom", "react-router-dom"],
            query: ["@tanstack/react-query"],
            charts: ["recharts"],
            maps: ["leaflet", "react-leaflet"],
          },
        },
      },
    },
  };
});
