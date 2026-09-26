<!-- First version made by Claude Sonnet 5 -->
<template>
  <label class="switch-wrapper">
    <span class="switch">
      <input type="checkbox" v-model="isOn">
      <span class="switch-track"></span>
      <span class="switch-thumb"></span>
    </span>
    <span class="switch-label">{{ label }}</span>
  </label>
</template>

<script lang="ts">
  import { defineComponent, ref, watch } from "vue";
  export default defineComponent({
    name: "ToggleSwitch"
  , props: { label: { type: String, required: true } }
  , emits: ["is-on"]
  , setup(props, { emit }) {
      const isOn = ref(false);
      watch(isOn, (newValue: boolean) => {
        console.log("It changed");
        emit("is-on", newValue);
      });
      return { label: props.label, isOn };
    }
  });
</script>

<style scoped>
.switch-wrapper {
  display:     inline-flex;
  align-items: center;
  gap:         var(--space-3);
  cursor:      pointer;
  user-select: none;
}

.switch-wrapper.disabled {
  cursor:  not-allowed;
  opacity: 0.5;
}

.switch {
  position:    relative;
  display:     inline-block;
  width:       44px;
  height:      26px;
  flex-shrink: 0;
}

.switch input {
  position: absolute;
  opacity:  0;
  width:    100%;
  height:   100%;
  margin:   0;
  cursor:   pointer;
  z-index:  1;
}

.switch input:disabled {
  cursor: not-allowed;
}

.switch-track {
  position:      absolute;
  inset:         0;
  background:    var(--clr-border-2);
  border-radius: 999px;
  transition:    background var(--transition);
}

.switch-thumb {
  position:      absolute;
  top:           3px;
  left:          3px;
  width:         20px;
  height:        20px;
  background:    var(--clr-surface);
  border-radius: 50%;
  box-shadow:    var(--shadow-sm);
  transition:    transform var(--transition);
}

.switch input:checked ~ .switch-track {
  background: var(--clr-primary);
}

.switch input:checked ~ .switch-thumb {
  transform: translateX(18px);
}

.switch input:focus-visible ~ .switch-track {
  box-shadow: 0 0 0 3px var(--clr-primary-lt);
}

.switch input:disabled ~ .switch-track {
  background: var(--clr-border);
}

.switch input:disabled:checked ~ .switch-track {
  background: var(--clr-muted);
}

/* Small variant */
.switch-sm {
  width:  34px;
  height: 20px;
}

.switch-sm .switch-thumb {
  width:  14px;
  height: 14px;
  top:    3px;
  left:   3px;
}

.switch-sm input:checked ~ .switch-thumb {
  transform: translateX(14px);
}

.switch-label {
  font-size: 0.9rem;
  color:     var(--clr-ink-2);
}

@media (prefers-reduced-motion: reduce) {
  .switch-track, .switch-thumb {
    transition: none;
  }
}

.switch-wrapper:not(.disabled):hover input:not(:checked) ~ .switch-track {
  background: color-mix(in srgb, var(--clr-border-2) 75%, var(--clr-primary) 25%);
}

</style>
