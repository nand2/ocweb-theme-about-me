import { createApp } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import { QueryClient, VueQueryPlugin } from '@tanstack/vue-query'
import './style.css'
import App from './App.vue'
import Body from './components/Body.vue'

// Theme config: Default values:
let themeConfig = {
  title: "<Your name>",
  subtitle: "<Your short bio>",
  email: "mail@example.com",
  location: "Earth",
  menu: [{title: 'Home', path: '/'}],
  externalLinks: [],
}
// Fetch the config of the theme, located at /themes/about-me/config.json
try {
  const themeConfigJson = await fetch('/themes/about-me/config.json')
  themeConfig = await themeConfigJson.json()
} catch (e) {
  console.log('Failed to fetch theme config, using the default one. Reason:', e)
}

// Create the router, based on the config above
const routes = themeConfig.menu.map(page => {
  return {
    path: page.path,
    component: Body,
    props: page.title && page.markdownFile ? { page } : {}
  }
})
const router = createRouter({
  history: createWebHashHistory(),
  routes: routes
})


// Create the vue app
const app = createApp(App)

// Tanstack Vue Query
const queryClient = new QueryClient()
app.use(VueQueryPlugin, { queryClient })
// Router
app.use(router)
// Inject theme config
app.provide('themeConfig', themeConfig)

app.mount('#app')

