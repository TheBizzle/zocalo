<template>

  <div
    ref="containerRef"
    class="split-layout"
    :class="{ 'is-dragging': isDragging }"
    @pointermove="onPointerMove"
    @pointerup="onPointerUp"
    @pointercancel="onPointerUp"
  >

    <aside class="pane left-pane" :style="{ width: `${asideWidth}px` }">
      <slot name="aside"></slot>
    </aside>

    <div
      class="resizer"
      :class="{ 'active': isDragging }"
      @pointerdown="onResizerPointerDown"
      role="separator"
      aria-orientation="vertical"
      :aria-valuenow="asideWidth"
      :aria-valuemin="minAsideWidth"
      :aria-valuemax="maxAsideWidth"
      tabindex="0"
      @keydown.left.prevent="asideWidth = Math.max(minAsideWidth, asideWidth - 16)"
      @keydown.right.prevent="asideWidth = Math.min(maxAsideWidth, asideWidth + 16)"
    >
      <div class="resizer-track" />
      <div class="resizer-handle">
        <span class="resizer-grip" />
        <span class="resizer-grip" />
        <span class="resizer-grip" />
      </div>
    </div>

    <main class="pane right-pane">
      <slot name="main"></slot>
    </main>

  </div>

</template>

<script setup lang="ts">

  import { ref, onUnmounted } from "vue";

  type Props =
    { initialAsideWidth?: number
    , minAsideWidth?:     number
    , maxAsideWidth?:     number
    }

  const props =
    withDefaults(
      defineProps<Props>()
    , { initialAsideWidth: 260
      , minAsideWidth:     160
      , maxAsideWidth:     600
      }
    );

  const asideWidth   = ref(props.initialAsideWidth);
  const isDragging   = ref(false);
  const containerRef = ref<HTMLElement | null>(null);

  function onResizerPointerDown(e: PointerEvent): void {
    e.preventDefault();
    isDragging.value = true;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }

  function onPointerMove(e: PointerEvent): void {
    if (isDragging.value && containerRef.value !== null) {
      const containerRect = containerRef.value.getBoundingClientRect();
      const newWidth      = e.clientX - containerRect.left;
      asideWidth.value    = Math.min(props.maxAsideWidth, Math.max(props.minAsideWidth, newWidth));
    }
  }

  function onPointerUp(): void {
    isDragging.value = false;
  }

  onUnmounted(
    () => {
      isDragging.value = false;
    }
  );


</script>

<style>
  :root {
    --color-accent:  #e8c547;
    --resizer-width: 6px;
  }
</style>

<style scoped>

  .left-pane {
    flex: 0 0 auto;
  }

  .pane {
    display:        flex;
    flex-direction: column;
    overflow:       hidden;
  }

  .resizer {

    flex:       0 0 var(--resizer-width);
    background: transparent;
    cursor:     col-resize;
    outline:    none;
    position:   relative;
    width:      var(--resizer-width);
    z-index:    10;

    /* Expands hit area without affecting layout */
    &::before {
      content:  "";
      position: absolute;
      inset:    0;
      left:     calc((20px - var(--resizer-width)) / -2);
      right:    calc((20px - var(--resizer-width)) / -2);
    }

  }

  .resizer-grip {
    display:          block;
    background-color: var(--clr-ink-2);
    border-radius:    50%;
    height:           3px;
    width:            3px;
  }

  /* Grip dots centred on the resizer */
  .resizer-handle {

    display:        flex;
    flex-direction: column;
    gap:            3px;

    position:       absolute;
    left:           50%;
    top:            50%;

    pointer-events:   none;
    transform:        translate(-50%, -50%);

  }

  .resizer-track {
    position:   absolute;
    inset:      0;
    background: var(--clr-border-2);
    transition: background-color 120ms ease;
  }

  .resizer:hover .resizer-track,
  .resizer.active .resizer-track {
    background-color: var(--color-accent);
  }

  /* keyboard focus ring */
  .resizer:focus-visible .resizer-track {
    background-color: var(--color-accent);
    box-shadow:       0 0 0 2px var(--color-accent);
  }

  .right-pane {
    flex:      1 1 0;
    min-width: 0; /* allow shrinking below content width */
  }

  .split-layout {
    display:        flex;
    flex-direction: row;
    overflow:       hidden;
    height:         100%;
    width:          100%;
  }

  .split-layout.is-dragging {
    cursor:      col-resize;
    user-select: none;
  }

</style>
