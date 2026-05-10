<template>

  <div ref="modalRef" class="modal-overlay animate-fade" v-if="isOpen" tabindex="-1"
       @click.self="close" @keyup.esc="handleEsc">
    <div class="modal-box animate-scale">
      <button class="btn-icon modal-close" @click="close">✕</button>
      <p class="section-eyebrow">Share your work</p>
      <h2 style="margin-bottom: var(--space-5)">Upload to gallery</h2>

      <div class="alert alert-danger" v-if="uploadError">{{ uploadError }}</div>

      <div class="form-stack">
        <div class="form-group">
          <label class="form-label">Title <span class="required">*</span></label>
          <input v-model="uploadForm.title" class="form-input" type="text"
                 placeholder="Name your work" />
        </div>
        <div class="form-group">
          <label class="form-label">Description</label>
          <textarea v-model="uploadForm.description" class="form-textarea"
                    placeholder="Tell us about it…" rows="2"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">File <span class="required">*</span></label>
          <div
            class="file-zone"
            :class="{ dragover: uploadDragging }"
            @click="triggerUploadInput"
            @dragover.prevent="uploadDragging = true"
            @dragleave="uploadDragging = false"
            @drop.prevent="onUploadDrop"
          >
            <input ref="uploadInputRef" type="file" style="display: none" @change="onUploadFile" />
            <div v-if="!uploadForm.fileName">
              <p style="font-size: 1.5rem; margin-bottom: 8px">📎</p>
              <p style="font-size: 0.9rem; color: var(--clr-ink-2)">Click or drag your file here</p>
            </div>
            <div v-else>
              <p style="font-size: 0.9rem; font-weight: 600; color: var(--clr-accent)">
                ✓ {{ uploadForm.fileName }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-ghost" @click="close">Cancel</button>
        <button class="btn btn-primary" @click="submitUpload" :disabled="uploading">
          <span v-if="uploading">Uploading...</span>
          <span v-else>Submit →</span>
        </button>
      </div>
    </div>
  </div>

</template>

<script lang="ts">

  import { defineComponent, nextTick, ref, watch } from "vue";
  import { useRoute                              } from "vue-router";

  export default defineComponent({
    name:       "UploadModal"
  , components: {}
  , props:      { isOpen: { type: Boolean, required: true } }
  , emits:      ["add-new-submission", "close-dialog"]
  , setup(props, { emit }) {

      useRoute();

      const modalRef        = ref<HTMLDivElement | null>(null);
      const uploadDragging  = ref(false);
      const uploadError     = ref("");
      const uploadForm      = ref({ title: "", description: "", fileName: "", fileData: null as File | null });
      const uploading       = ref(false);
      const uploadInputRef  = ref<HTMLInputElement | null>(null);

      watch(
        () => props.isOpen
      , async (isOpen) => {
          if (isOpen) {
            await nextTick();
            modalRef.value?.focus();
          }
        }
      );

      function close(): void {
        emit("close-dialog");
      }

      function handleEsc(e: KeyboardEvent): void {
        console.warn("Got here", e.target);
        const target  = e.target as HTMLElement;
        const isInput = ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName);
        if (!isInput) {
          close();
        } else {
          modalRef.value?.focus();
        }
      }

      function onUploadDrop(e: DragEvent): void {
        uploadDragging.value = false;
        const file           = e.dataTransfer?.files[0];
        if (file !== undefined) {
          setUploadFile(file);
        }
      }

      function onUploadFile(e: Event): void {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (file) {
          setUploadFile(file);
        }
      }

      function setUploadFile(file: File): void {
        uploadForm.value.fileName = file.name;
        uploadForm.value.fileData = file;
      }

      async function submitUpload(): Promise<void> {

        uploadError.value = "";

        if (uploadForm.value.title.trim() === "") {
          uploadError.value = "Please enter a title.";
          return;
        }

        if (uploadForm.value.fileData === null) {
          uploadError.value = "Please attach a file.";
          return;
        }

        uploading.value = true;

        try {
          // TODO: API call
          await new Promise(r => setTimeout(r, 800));
          const submission =
            { id:           Date.now().toString()
            , title:        uploadForm.value.title.trim()
            , description:  uploadForm.value.description
            , thumbnail:    null
            , submittedAt:  new Date()
            , commentCount: 0
            , comments:     []
            };
          emit("add-new-submission", submission);
          uploadForm.value = { title: "", description: "", fileName: "", fileData: null };
          close();
        } catch (err: unknown) {
          if (err instanceof Error) {
            uploadError.value = err.message;
          } else {
            uploadError.value = "Upload failed. Please try again.";
          }
        } finally {
          uploading.value = false;
        }

      }

      function triggerUploadInput(): void {
        uploadInputRef.value?.click();
      }

      return { close, handleEsc, modalRef, onUploadDrop, onUploadFile, setUploadFile, submitUpload
             , triggerUploadInput, uploadDragging, uploadError, uploadForm, uploading, uploadInputRef };

    }
  });

</script>

<style scoped>

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
  }

  .modal-footer {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
    margin-top:      var(--space-5);
  }

</style>
