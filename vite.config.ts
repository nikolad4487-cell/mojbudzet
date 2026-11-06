import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'
export default defineConfig({plugins:[react(),tailwindcss(),VitePWA({registerType:'prompt',includeAssets:['icon.svg'],manifest:{name:'Moj Budžet',short_name:'Moj Budžet',lang:'hr',start_url:'/',display:'standalone',theme_color:'#17634c',background_color:'#f5f6f1',icons:[{src:'/icon.svg',sizes:'any',type:'image/svg+xml',purpose:'any'}]},workbox:{navigateFallback:'/index.html',runtimeCaching:[]}})]})
