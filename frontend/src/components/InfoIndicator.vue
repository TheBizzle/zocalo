<template>
  <Tooltip :aria-label="ariaLabel">
    <svg viewBox="0 0 16 16" width="14" height="14" fill="currentColor">
      <circle cx="8" cy="8" r="7" fill="none" stroke="currentColor" stroke-width="1.5" />
      <path d="M8 4a.75.75 0 1 1 0 1.5A.75.75 0 0 1 8 4z" />
      <path d="M8 7c.414 0 .75.336.75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 7z" />
    </svg>
    <template #tooltip>
      <slot />
    </template>
  </Tooltip>
</template>

<script setup lang="ts">
  import Tooltip from "./Tooltip.vue";
  defineProps<{ ariaLabel?: string }>();
</script>
