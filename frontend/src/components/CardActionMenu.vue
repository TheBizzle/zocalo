<!-- First version made by Claude Sonnet 5.5 -->
<template>
  <div ref="root" class="card-actions">
    <button
      ref="button"
      type="button"
      class="card-actions__trigger"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      @click.stop="toggle"
      @keydown="onTriggerKeydown"
    >
      <span class="card-actions__dot" aria-hidden="true" />
      <span class="card-actions__dot" aria-hidden="true" />
      <span class="card-actions__dot" aria-hidden="true" />
    </button>

    <div
      v-if="isOpen"
      ref="menu"
      class="card-actions__menu"
      role="menu"
      aria-label="More actions"
      @click.stop
      @keydown="onMenuKeydown"
    >
      <button type="button" role="menuitem" class="card-actions__item" @click="onExportZip" >
        <svg
          class="card-actions__item-icon"
          viewBox="0 0 24 24"
          width="18"
          height="18"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <polyline points="21 8 21 21 3 21 3 8" />
          <rect x="1" y="3" width="22" height="5" />
          <line x1="10" y1="12" x2="14" y2="12" />
        </svg>
        Export to ZIP
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">

  import { nextTick, onBeforeUnmount, onMounted, ref } from "vue";

  const emit = defineEmits<(e: "export-zip") => void>();

  const isOpen = ref(false);
  const root   = ref<HTMLElement       | null>(null);
  const button = ref<HTMLButtonElement | null>(null);
  const menu   = ref<HTMLElement       | null>(null);

  function getItems(): Array<HTMLElement> {
    return (menu.value === null) ? [] : Array.from(menu.value.querySelectorAll("[role=\"menuitem\"]"));
  }

  async function open(focus: "first" | "last"): Promise<void> {
    isOpen.value = true;
    await nextTick();
    const items  = getItems();
    const index = focus === "last" ? items.length - 1 : 0;
    items[index]?.focus();
  }

  function close(returnFocus: boolean): void {
    if (isOpen.value) {
      isOpen.value = false;
      if (returnFocus) {
        button.value?.focus();
      }
    }
  }

  function toggle(): void {
    if (isOpen.value) {
      close(false);
    } else {
      void open("first");
    }
  }

  function onTriggerKeydown(event: KeyboardEvent): void {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      void open("first");
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      void open("last");
    }
  }

  function onMenuKeydown(event: KeyboardEvent): void {

    const items   = getItems();
    const current = items.indexOf(document.activeElement as HTMLElement);

    switch (event.key) {
      case "Escape":
        event.preventDefault();
        close(true);
        break;
      case "ArrowDown":
        event.preventDefault();
        items[(current + 1) % items.length]?.focus();
        break;
      case "ArrowUp":
        event.preventDefault();
        items[(current - 1 + items.length) % items.length]?.focus();
        break;
      case "Home":
        event.preventDefault();
        items[0]?.focus();
        break;
      case "End":
        event.preventDefault();
        items[items.length - 1]?.focus();
        break;
      case "Tab":
        close(false);
        break;
      default:
    }

  }

  function onExportZip(): void {
    emit("export-zip");
    close(true);
  }

  function onDocumentPointerDown(event: PointerEvent): void {
    if (isOpen.value && root.value?.contains(event.target as Node) === false) {
      close(false);
    }
  }

  onMounted(      () => { document.   addEventListener("pointerdown", onDocumentPointerDown); });
  onBeforeUnmount(() => { document.removeEventListener("pointerdown", onDocumentPointerDown); });

</script>

<style scoped>

  .card-actions {
    position: absolute;
    top:      var(--space-4);
    right:    var(--space-4);
    z-index:  10;
  }

  .card-actions__trigger {
    display:         flex;
    align-items:     center;
    justify-content: center;

    height: 30px;
    width:  30px;

    background:    var(--clr-surface);
    border:        1px solid var(--clr-muted);
    border-radius: 50%;
    cursor:        pointer;
    gap:           3px;
    padding:       0;
    transition:    background var(--transition), border-color var(--transition);
  }

  .card-actions__trigger:hover,
  .card-actions__trigger[aria-expanded='true'] {
    background:   var(--clr-primary-lt);
    border-color: var(--clr-ink-3);
  }

  .card-actions__trigger:focus-visible {
    outline:        2px solid var(--clr-primary);
    outline-offset: 2px;
  }

  .card-actions__dot {
    height: 3px;
    width:  3px;

    background:    var(--clr-ink-2);
    border-radius: 50%;
    flex:          none;
    transition:    background var(--transition);
  }

  .card-actions__trigger:hover .card-actions__dot,
  .card-actions__trigger[aria-expanded='true'] .card-actions__dot {
    background: var(--clr-ink);
  }

  .card-actions__menu {
    position: absolute;
    top:      calc(100% + 8px);
    right:    0;

    background:    var(--clr-surface);
    border:        1px solid var(--clr-border);
    border-radius: var(--radius-md);
    min-width:     180px;
    padding:       6px;
  }

  .card-actions__item {
    display: flex;

    align-items:   center;
    background:    transparent;
    border:        none;
    border-radius: 8px;
    color:         var(--clr-ink);
    cursor:        pointer;
    font-family:   var(--font-body);
    font-size:     0.9375rem;
    gap:           10px;
    line-height:   1.4;
    padding:       9px 12px;
    text-align:    left;
    width:         100%;
  }

  .card-actions__item:hover,
  .card-actions__item:focus-visible {
    background: var(--clr-primary-lt);
  }

  .card-actions__item:focus-visible {
    outline:        2px solid var(--clr-primary);
    outline-offset: -2px;
  }

  .card-actions__item-icon {
    flex: none;
  }

</style>
