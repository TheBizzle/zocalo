<template>
  <span class="tooltip-wrapper" tabindex="0" :aria-label="ariaLabel">
    <slot />
    <span class="tooltip" role="tooltip">
      <slot name="tooltip" />
    </span>
  </span>
</template>

<script setup lang="ts">
  defineProps<{ ariaLabel?: string }>();
</script>

<style scoped>

  .tooltip {
    background:     var(--clr-ink);
    border:         1px solid var(--clr-ink-2);
    border-radius:  var(--radius-sm);
    bottom:         calc(100% + var(--space-2));
    box-shadow:     var(--shadow-md);
    color:          var(--clr-surface);
    font-family:    var(--font-body);
    font-size:      0.78rem;
    font-weight:    400;
    left:           50%;
    line-height:    1.5;
    opacity:        0;
    padding:        var(--space-2) var(--space-3);
    pointer-events: none;
    position:       absolute;
    transform:      translateX(-50%) translateY(4px);
    transition:     opacity var(--transition), transform var(--transition);
    white-space:    normal;
    width:          320px;
    z-index:        10;
  }

  .tooltip-wrapper {
    align-items: center;
    color:       var(--clr-muted);
    cursor:      default;
    display:     inline-flex;
    margin-left: var(--space-1);
    position:    relative;
    transition:  color var(--transition);
  }

  .tooltip-wrapper:hover,
  .tooltip-wrapper:focus {
    color:   var(--clr-ink-2);
    outline: none;
  }

  .tooltip-wrapper:hover .tooltip,
  .tooltip-wrapper:focus .tooltip {
    opacity:        1;
    pointer-events: auto;
    transform:      translateX(-50%) translateY(0);
  }

</style>
