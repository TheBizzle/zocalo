<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="create-form card animate-fade">
    <button class="btn-back" @click.stop="cancelForm">
      <svg width="24" height="19" viewBox="0 0 20 16" fill="none" aria-hidden="true"
           xmlns="http://www.w3.org/2000/svg">
        <path d="M17 8H3M3 8l4.5-4.5M3 8l4.5 4.5" stroke="currentColor" stroke-width="1.5"
              stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
    <h2 style="margin-bottom: var(--space-6)">Create a new gallery</h2>

    <div class="alert alert-danger" v-if="errorMsg">{{ errorMsg }}</div>
    <div class="alert alert-success" v-if="successMsg">{{ successMsg }}</div>

    <div class="form-grid">

      <!-- Name -->
      <div class="form-group span-2">
        <label class="form-label">Gallery name <span class="required">*</span></label>
        <input v-model="form.name" class="form-input" type="text"
               placeholder="e.g. Math 102 > Spring 2026 > Section 2" />
      </div>

      <!-- Template -->
      <div class="form-group span-2">
        <label class="form-label">Template <span class="required">*</span></label>
        <select v-model="form.template" class="form-select">
          <option value="">— Select a template —</option>
          <option v-for="t in templates" :key="t.id" :value="t.id" :disabled="t.isDisabled">
            {{ t.name }}
          </option>
        </select>
        <span class="form-hint" v-if="selectedTemplate">{{ selectedTemplate.description }}</span>
      </div>

      <!-- Moderation toggle -->
      <div class="form-group span-2">
        <label class="form-label">
          Enable moderation?
          <InfoIndicator aria-label="Moderation info">
              <strong>Off</strong>: Student uploads instantly appear in the public gallery.<br><br>
              <strong>On</strong>: Each upload must be approved by you on the moderation page before
                                   becoming visible to everyone else.
          </InfoIndicator>
        </label>
        <Switcher v-model="form.isModerated" />
      </div>

      <!-- Description -->
      <div class="form-group span-2">
        <label class="form-label">
          Description <span class="text-muted" style="font-weight: 400">(optional)</span>
        </label>
        <textarea v-model="form.description" class="form-textarea" rows="3"></textarea>
      </div>

      <!-- Starter data -->
      <div v-if="hasStarter" class="form-group span-2">
        <label class="form-label">
          Starter data
          <span class="text-muted" style="font-weight: 400">(optional)</span>
        </label>

        <div class="starter-data-box">

          <div class="starter-type-row">
            <label style="font-size: 0.85rem; font-weight: 500; color: var(--clr-ink-2)">
              Data encoding:
            </label>
            <fieldset class="starter-option-row toggle-group" :disabled="uploadedFileName !== null">
              <div class="toggle-option" style="min-width: 90px">
                <input id="dtype-auto" type="radio" v-model="form.encoding" value="auto" />
                <label for="dtype-auto" style="padding: 6px 12px; font-size: 0.8rem">Auto-detect</label>
              </div>
              <div class="toggle-option" style="min-width: 90px">
                <input id="dtype-text" type="radio" v-model="form.encoding" value="text" />
                <label for="dtype-text" style="padding: 6px 12px; font-size: 0.8rem">Plain text</label>
              </div>
              <div class="toggle-option" style="min-width: 90px">
                <input id="dtype-b64" type="radio" v-model="form.encoding" value="base64" />
                <label for="dtype-b64" style="padding: 6px 12px; font-size: 0.8rem">Base64</label>
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
            v-model="form.starterData"
            class="form-textarea"
            placeholder="Or type / paste your starter data here..."
            rows="5"
            style="margin-top: var(--space-3); font-family: monospace; font-size: 0.82rem"
          ></textarea>

        </div>
      </div>
    </div>

    <div class="form-actions">
      <button class="btn btn-ghost" @click="cancelForm">Cancel</button>
      <button class="btn btn-primary btn-lg" @click="submit" :disabled="isLoading">
        <span v-if="isLoading">Creating...</span>
        <span v-else>Create gallery →</span>
      </button>
    </div>
  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, reactive, ref } from "vue";

  import { activities       } from "@/core/Activity.ts";
  import { uploadNewGallery } from "@/core/uploadNewGallery.ts";

  import InfoIndicator from "./InfoIndicator.vue";
  import Switcher      from "./Switcher.vue";

  type Template =
    { id:          string
    , name:        string
    , isDisabled:  boolean
    , description: string
    }

  export default defineComponent({
    name:       "CreateGalleryForm"
  , components: { InfoIndicator, Switcher }
  , emits:      ["canceled", "created"]
  , setup(_, { emit }) {

      const isDragging       = ref(false);
      const errorMsg         = ref<string | null>(null);
      const fileInput        = ref<HTMLInputElement | null>(null);
      const isLoading        = ref(false);
      const successMsg       = ref<string | null>(null);
      const uploadedFileName = ref<string | null>(null);

      const templates: Array<Template> =
        [ { id: "geogebra",      name: "GeoGebra",             isDisabled: false, description: "Students upload GeoGebra constructions" }
        , { id: "google-docs",   name: "Google Docs",          isDisabled: false, description: "Students upload content from a seed Google Doc" }
        , { id: "netlogo-model", name: "NetLogo",              isDisabled:  true, description: "Students upload NetLogo models" }
        , { id: "netlogo-world", name: "NetLogo + world",      isDisabled:  true, description: "Students upload NetLogo models and world states" }
        , { id: "segregation",   name: "NetLogo: Segregation", isDisabled: false, description: "Students upload variations of NetLogo's Segregation model" }
        , { id: "netsblox",      name: "NetsBlox",             isDisabled:  true, description: "Students upload NetsBlox programs" }
        , { id: "Demo",          name: "Demo",                 isDisabled: false, description: "Simple demo gallery with a grid of images and files" }
        ];

      const form = reactive({
        name:        ""
      , template:    ""
      , isModerated: false
      , description: ""
      , encoding:    "auto"
      , starterData: ""
      });

      const selectedTemplate = computed(() => templates.find(t => t.id === form.template) ?? null);

      const hasStarter = computed<boolean>(
        () => {
          const name = (selectedTemplate.value?.id ?? "Demo").toLowerCase();
          const mode = activities[name]?.starterMode ?? "none";
          return mode !== "none";
        }
      );

      function triggerFileInput (): void {
        fileInput.value?.click();
      }

      const detectedType = ref<string | null>(null);

      const trueReader = new FileReader();
      trueReader.onloadend = (event: ProgressEvent): void => {
        form.starterData = (event.target as FileReader).result as string;
      };

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

      function readFile(file: File): void {
        uploadedFileName.value = file.name;
        const mode             = form.encoding;
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

      function onDrop(e: DragEvent): void {
        isDragging.value = false;
        const file       = e.dataTransfer!.files[0]!;
        readFile(file);
      }

      function clearFile(): void {
        uploadedFileName.value = null;
        form.starterData       = "";
        detectedType.value     = null;
        if (fileInput.value !== null) {
          fileInput.value.value = "";
        }
      }

      function resetForm(): void {
        form.name        = "";
        form.template    = "";
        form.isModerated   = false;
        form.description = "";
        form.encoding    = "auto";
        form.starterData = "";
        errorMsg.value   = null;
        successMsg.value = null;
        clearFile();
      }

      function cancelForm(): void {
        resetForm();
        emit("canceled");
      }

      async function submit(): Promise<void> {

        errorMsg.value   = null;
        successMsg.value = null;

        if (form.name.trim() === "") {
          errorMsg.value = "Please enter a gallery name.";
          return;
        }

        if (form.template === "") {
          errorMsg.value = "Please select a template.";
          return;
        }

        isLoading.value = true;

        try {

          const newGalleryR =
            await uploadNewGallery( form.name, form.template, form.isModerated
                                  , form.description, form.starterData);

          newGalleryR.fold(
            (error  ) => { errorMsg.value = error.message; }
          , (gallery) => {
              successMsg.value = `Gallery "${gallery.name}" created!`;
              emit("created", gallery);
            }
          );

          resetForm();

        } catch (err: unknown) {
          if (err instanceof Error) {
            errorMsg.value = err.message;
          } else {
            errorMsg.value = "Could not create gallery. Please try again.";
          }
        } finally {
          isLoading.value = false;
        }

      }

      return {
        cancelForm, clearFile, detectedType, errorMsg, fileInput, form, hasStarter, isDragging, isLoading
      , onFileChange , onDrop, resetForm, selectedTemplate, submit, successMsg, templates, triggerFileInput
      , uploadedFileName
      };

    }
  });

</script>

<style scoped>

  .create-form {
    max-width: 760px;
    padding:   var(--space-5) var(--space-7) var(--space-7);
  }

  .form-grid {
    display:               grid;
    grid-template-columns: 1fr 1fr;
    gap:                   var(--space-5);
    margin-bottom:         var(--space-6);
  }

  .span-2 {
    grid-column: span 2;
  }

  .starter-data-box {
    border:         1px solid var(--clr-border);
    border-radius:  var(--radius-lg);
    padding:        var(--space-4);
    background:     var(--clr-surface-2);
    display:        flex;
    flex-direction: column;
    gap:            var(--space-3);
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

  .form-actions {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
  }

  .btn-back {
    display:     inline-flex;
    align-items: center;
    gap:         6px;

    background:    transparent;
    border:        none;
    border-radius: 6px;
    cursor:        pointer;
    margin:        0 0 18px;
    padding:       4px 2px;
    font-size:     22px;
    transition:    background 0.15s, transform 0.1s;
  }

  .btn-back:hover {
    background-color: rgb(225, 225, 225);
  }

  .btn-link {
    background:  none;
    border:      none;
    cursor:      pointer;
    color:       var(--clr-primary);
    font-family: var(--font-body);
    font-size:   0.85rem;
  }

  .btn-link:hover {
    text-decoration: underline;
  }

  .noticeable {
    color: black;
  }

  @media (max-width: 560px) {
    .form-grid {
      grid-template-columns: 1fr;
    }
    .span-2 {
      grid-column: span 1;
    }
  }

</style>
