<!-- First version made by Claude Opus 4.6 -->
<template>
  <button
    type="button"
    role="switch"
    :aria-checked="modelValue"
    class="switch"
    :class="{ 'switch--on': modelValue }"
    @click="$emit('update:modelValue', !modelValue)"
  >
    <span class="switch-thumb" />
  </button>
</template>

<script setup lang="ts">
  defineProps<{ modelValue: boolean }>();
  defineEmits<(e: "update:modelValue", val: boolean) => void>();
</script>

<style scoped>

  /* "Moderation" switch */
  .switch-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .switch {
    position: relative;
    width: 44px;
    height: 24px;
    border-radius: var(--radius-xl);
    border: 1.5px solid var(--clr-border-2);
    cursor: pointer;
    background: var(--clr-surface-2);
    transition: background var(--transition), border-color var(--transition);
    flex-shrink: 0;
    padding: 0;
  }

  .switch--on {
    background: var(--clr-primary);
    border-color: var(--clr-primary-dk);
  }

  .switch-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--clr-surface);
    box-shadow: var(--shadow-sm);
    transition: transform var(--transition);
  }

  .switch--on .switch-thumb {
    transform: translateX(20px);
  }

  .switch-label {
    font-family: var(--font-body);
    font-size: 0.875rem;
    color: var(--clr-muted);
    transition: color var(--transition);
  }

  .switch-label.active {
    color: var(--clr-ink);
    font-weight: 500;
  }

</style>
