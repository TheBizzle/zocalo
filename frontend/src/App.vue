<template>
  <div id="app">
    <AppNavbar />
    <router-view v-slot="{ Component }">
      <transition name="page" mode="out-in">
        <component :is="Component" />
      </transition>
    </router-view>
  </div>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import AppNavbar from "./components/AppNavbar.vue";
export default defineComponent({ components: { AppNavbar } });
</script>

<style>
.page-enter-active, .page-leave-active {
  transition: opacity 200ms ease, transform 200ms ease;
}
.page-enter-from { opacity: 0; transform: translateY(6px); }
.page-leave-to   { opacity: 0; transform: translateY(-4px); }
</style>
