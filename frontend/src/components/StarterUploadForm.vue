<template>

  <div class="starter-data-box">

    <div class="starter-type-row">
      <label style="font-size: 0.85rem; font-weight: 500; color: var(--clr-ink-2)">
        Data encoding:
      </label>
      <fieldset class="starter-option-row toggle-group" :disabled="uploadedFileName !== null">
        <div class="toggle-option" style="min-width: 90px">
          <label style="padding: 6px 12px; font-size: 0.8rem">Auto-detect</label>
          <input type="radio" v-model="encoding" value="auto" />
        </div>
        <div class="toggle-option" style="min-width: 90px">
          <label style="padding: 6px 12px; font-size: 0.8rem">Plain text</label>
          <input type="radio" v-model="encoding" value="text" />
        </div>
        <div class="toggle-option" style="min-width: 90px">
          <label style="padding: 6px 12px; font-size: 0.8rem">Base64</label>
          <input type="radio" v-model="encoding" value="base64" />
        </div>
      </fieldset>
    </div>

    <!-- File upload zone -->
    <div class="file-zone" :class="{ dragover: isDragging }" @click="triggerFileInput"
         @dragover.prevent="isDragging = true" @dragleave="isDragging = false"
         @drop.prevent="onDrop">
      <input ref="fileInput" type="file" style="display: none" @change="onFileChange" />
      <div v-if="!uploadedFileName">
        <p style="font-size: 1.5rem; margin-bottom: 8px">📄</p>
        <p style="font-size: 0.9rem; color: var(--clr-ink-2)">
          Click or drag a file here to populate the box below
        </p>
      </div>
      <div v-else>
        <p style="font-size: 0.9rem; font-weight: 600; color: var(--clr-accent)">
          ✓ {{ uploadedFileName }}
        </p>
        <p v-if="detectedType" class="form-hint noticeable">
          Auto-detected as: <strong>{{ detectedType }}</strong>
        </p>
        <button class="btn-link" style="font-size: 0.8rem" @click.stop="clearFile">Remove</button>
      </div>
    </div>

    <!-- Text area -->
    <textarea
      v-model="starterData"
      class="form-textarea"
      placeholder="Or type / paste your starter data here..."
      rows="5"
      style="margin-top: var(--space-3); font-family: monospace; font-size: 0.82rem"
    ></textarea>

  </div>

</template>

<script setup lang="ts">

  import { ref } from "vue";

  const detectedType     = ref<string | null>(null);
  const encoding         = ref<"auto" | "text" | "base64">("auto");
  const fileInput        = ref<HTMLInputElement | null>(null);
  const isDragging       = ref(false);
  const starterData      = ref<string | undefined>(undefined);
  const uploadedFileName = ref<string | null>(null);

  const trueReader = new FileReader();
  trueReader.onloadend = (event: ProgressEvent): void => {
    starterData.value = (event.target as FileReader).result as string;
  };

  defineExpose({
    getData(): string {
      return starterData.value ?? "";
    }

  , reset(): void {
      encoding.value    = "auto";
      starterData.value = "";
      clearFile();
    }
  });

  function triggerFileInput(): void {
    fileInput.value?.click();
  }

  function clearFile(): void {
    uploadedFileName.value = null;
    starterData.value      = "";
    detectedType.value     = null;
    if (fileInput.value !== null) {
      fileInput.value.value = "";
    }
  }

  function readFileAuto(file: File): void {

    const reader = new FileReader();
    reader.onloadend = (e: ProgressEvent): void => {

      const arr   = new Uint8Array((e.target as FileReader).result as ArrayBuffer);
      let isASCII = true;

      for (const byte of arr) {
        // Checking for values <= 127 didn't suffice;
        // The en-dash, for example, is in Extended ASCII at 377 AKA 0x226
        if (byte === 0) {
          isASCII = false;
          break;
        }
      }

      if (isASCII) {
        trueReader.readAsText(file);
        detectedType.value = "Plain text";
      } else {
        trueReader.readAsDataURL(file);
        detectedType.value = "Base64";
      }

    };

    reader.readAsArrayBuffer(file);

  }

  function onDrop(e: DragEvent): void {
    isDragging.value = false;
    const file       = e.dataTransfer!.files[0]!;
    readFile(file);
  }

  function readFile(file: File): void {
    uploadedFileName.value = file.name;
    const mode             = encoding.value;
    switch (mode) {
      case "text":
        trueReader.readAsText(file);
        break;
      case "base64":
        trueReader.readAsDataURL(file);
        break;
      case "auto":
        readFileAuto(file);
        break;
      default:
        console.warn(`Unknown reading mode: ${mode}`);
    }
  }

  function onFileChange(e: Event): void {
    const file = (e.target as HTMLInputElement).files![0]!;
    readFile(file);
  }

</script>

<style scoped>

  .starter-data-box {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-3);
    background:     var(--clr-surface);
    border-radius:  0 0 var(--radius-md) var(--radius-md);
    padding:        var(--space-4);
  }

  .starter-type-row {
    display:     flex;
    align-items: center;
    gap:         var(--space-3);
    flex-wrap:   wrap;
  }

  .starter-option-row {
    display:        flex;
    flex-direction: row;
    flex-grow:      1;
    border:         none;
    user-select:    none;
  }

</style>
