<!-- First version made by Claude Opus 4.6 -->
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
          <label class="form-label">Your contribution<span class="required">*</span></label>
          <div
            class="file-zone"
            :class="{ dragover: uploadDragging }"
            @click="triggerUploadInput"
            @dragover.prevent="uploadDragging = true"
            @dragleave="uploadDragging = false"
            @drop.prevent="onUploadDrop"
          >
            <input ref="uploadInputRef" type="file" style="display: none" @change="onUploadFile" />
            <div v-if="!uploadForm.uploadName">
              <p style="font-size: 1.5rem; margin-bottom: 8px">📎</p>
              <p style="font-size: 0.9rem; color: var(--clr-ink-2)">Click, or drag your file here</p>
            </div>
            <div v-else>
              <p style="font-size: 0.9rem; font-weight: 600; color: var(--clr-accent)">
                ✓ {{ uploadForm.uploadName }}
              </p>
            </div>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Preview image<span class="required">*</span></label>
          <div
            class="file-zone"
            :class="{ dragover: imageDragging }"
            @click="triggerImageInput"
            @dragover.prevent="imageDragging = true"
            @dragleave="imageDragging = false"
            @drop.prevent="onImageDrop"
          >
            <input ref="imageInputRef" type="file" style="display: none" @change="onImageFile" />
            <div v-if="!uploadForm.imageName">
              <p style="font-size: 1.5rem; margin-bottom: 8px">🖼️</p>
              <p style="font-size: 0.9rem; color: var(--clr-ink-2)">Click, or drag your image here</p>
            </div>
            <div v-else>
              <p style="font-size: 0.9rem; font-weight: 600; color: var(--clr-accent)">
                ✓ {{ uploadForm.imageName }}
              </p>
            </div>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Description</label>
          <textarea v-model="uploadForm.description" class="form-textarea"
                    placeholder="Describe your work" rows="2"></textarea>
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

  import { readFileAsBase64 } from "@/composables/readFileAsBase64.ts";
  import { readFileAsText   } from "@/composables/readFileAsText.ts";

  import { authorizedFetch } from "@/core/StudentAuth.ts";

  export default defineComponent({
    name:       "UploadModal"
  , components: {}
  , props:      { isOpen: { type: Boolean, required: true } }
  , emits:      ["add-new-submission", "close-dialog"]
  , setup(props, { emit }) {

      const route  = useRoute();
      const nanoID = route.params["nanoid"] as string;

      const modalRef        = ref<HTMLDivElement | null>(null);

      const imageDragging  = ref(false);
      const imageInputRef  = ref<HTMLInputElement | null>(null);

      const uploadDragging  = ref(false);
      const uploadInputRef  = ref<HTMLInputElement | null>(null);

      const uploadError     = ref("");
      const uploading       = ref(false);

      const uploadForm =
        ref(
          { description: ""
          , imageFile:   null as File | null
          , imageName:   ""
          , uploadFile:  null as File | null
          , uploadName:  ""
          }
        );

      watch(
        () => props.isOpen
      , async (isOpen: boolean) => {
          if (isOpen) {
            await nextTick();
            modalRef.value?.focus();
          }
        }
      );

      function close(): void {
        emit("close-dialog");
      }

      let isPresentingFileChooser = false;

      [uploadInputRef, imageInputRef].forEach(
        (inp) => {
          watch(inp, (input) => {
            input?.addEventListener("click", () => {
              isPresentingFileChooser = true;
            });
            input?.addEventListener("change", () => {
              isPresentingFileChooser = false;
            });
          }, { immediate: true });
        }
      );

      function handleEsc(e: KeyboardEvent): void {
        if (!isPresentingFileChooser) {
          const target  = e.target as HTMLElement;
          const isInput = ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName);
          if (!isInput) {
            close();
          } else {
            modalRef.value?.focus();
          }
        } else {
          isPresentingFileChooser = false;
        }
      }

      function onImageDrop(e: DragEvent): void {
        uploadDragging.value = false;
        const file           = e.dataTransfer?.files[0];
        if (file !== undefined) {
          setImageFile(file);
        }
      }

      function onImageFile(e: Event): void {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (file !== undefined) {
          setImageFile(file);
        }
      }

      function triggerImageInput(): void {
        imageInputRef.value?.click();
      }

      function setImageFile(file: File): void {
        uploadForm.value.imageName = file.name;
        uploadForm.value.imageFile = file;
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
        if (file !== undefined) {
          setUploadFile(file);
        }
      }

      function triggerUploadInput(): void {
        uploadInputRef.value?.click();
      }

      function setUploadFile(file: File): void {
        uploadForm.value.uploadName = file.name;
        uploadForm.value.uploadFile = file;
      }

      async function submitUpload(): Promise<void> {

        uploadError.value = "";

        if (uploadForm.value.uploadFile === null) {
          uploadError.value = "Please attach a file.";
          return;
        }

        if (uploadForm.value.imageFile === null) {
          uploadError.value = "Please attach an image.";
          return;
        }

        uploading.value = true;

        try {

          const metadata = JSON.stringify({ description: uploadForm.value.description });

          const postData = new FormData();
          postData.append("data"    , uploadForm.value.uploadFile);
          postData.append("image"   , uploadForm.value. imageFile);
          postData.append("metadata",                    metadata);
          const options = { method: "POST", body: postData };

          const url    = `/api/galleries/${nanoID}/student/submission`;
          const result = await authorizedFetch(url, options);

          if (result.ok) {

            const response   = await result.json() as { id: number, name: string };
            const data       = await readFileAsText(  uploadForm.value.uploadFile);
            const image      = await readFileAsBase64(uploadForm.value. imageFile);

            const submission =
              { id:           response.id
              , uploadName:   response.name
              , data
              , image
              , isOwner:      true
              , canModerate:  false
              , metadata
              , comments:     []
              , creationTime: new Date()
              };

            emit("add-new-submission", submission);
            uploadForm.value = { description: "", imageFile: null, imageName: "", uploadFile: null, uploadName: "" };
            close();

          } else {
            uploadError.value = await result.text();
          }

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

      return { close, handleEsc, imageDragging, imageInputRef, modalRef, onImageDrop, onImageFile
             , onUploadDrop, onUploadFile, setUploadFile, submitUpload, triggerImageInput
             , triggerUploadInput, uploadDragging, uploadError, uploadForm, uploading, uploadInputRef };

    }
  });

</script>

<style scoped>

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
    overflow-y:     auto;
    padding-right:  var(--space-6);
  }

  .modal-footer {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
    margin-top:      var(--space-5);
  }

</style>
