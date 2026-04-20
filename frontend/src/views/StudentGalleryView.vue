<template>
  <div>
    <!-- Custom student navbar -->
    <nav class="student-nav">
      <span class="navbar-brand" style="pointer-events: none">
        <span class="brand-dot"></span>
        zócalo
      </span>
      <div class="gallery-title-pill">{{ galleryName }}</div>
      <div style="display: flex; gap: var(--space-3); align-items: center">
        <button class="btn btn-primary btn-sm" @click="uploadModalOpen = true">
          + Upload work
        </button>
      </div>
    </nav>

    <div class="page-wrapper-wide">

      <!-- Hero area -->
      <div class="gallery-hero animate-fade" v-if="galleryDescription">
        <p class="gallery-description">{{ galleryDescription }}</p>
      </div>

      <!-- Gallery grid -->
      <div v-if="submissions.length === 0" class="empty-state">
        <div class="empty-state-icon">🖼️</div>
        <h3>Nothing here yet</h3>
        <p>Be the first to upload your work!</p>
        <button class="btn btn-primary" style="margin-top: 16px" @click="uploadModalOpen = true">
          Upload your work
        </button>
      </div>

      <div class="gallery-grid stagger animate-fade" v-else>
        <div
          v-for="item in submissions" :key="item.id"
          class="gallery-item"
          @click="openItem(item)"
        >
          <div class="gallery-item-thumb">
            <img v-if="item.thumbnail" :src="item.thumbnail" :alt="item.title" />
            <div v-else class="no-thumb">📄</div>
          </div>
          <div class="gallery-item-info">
            <div class="gallery-item-title">{{ item.title }}</div>
            <div class="gallery-item-meta">
              {{ item.commentCount }} comment{{ item.commentCount !== 1 ? 's' : '' }}
              · {{ formatDate(item.submittedAt) }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ─── Upload modal ─── -->
    <div class="modal-overlay animate-fade" v-if="uploadModalOpen" @click.self="uploadModalOpen = false">
      <div class="modal-box animate-scale">
        <button class="btn-icon modal-close" @click="uploadModalOpen = false">✕</button>
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
          <button class="btn btn-ghost" @click="uploadModalOpen = false">Cancel</button>
          <button class="btn btn-primary" @click="submitUpload" :disabled="uploading">
            <span v-if="uploading">Uploading…</span>
            <span v-else>Submit →</span>
          </button>
        </div>
      </div>
    </div>

    <!-- ─── Item detail modal ─── -->
    <div class="modal-overlay animate-fade" v-if="activeItem" @click.self="activeItem = null">
      <div class="modal-box item-detail-modal animate-scale">
        <button class="btn-icon modal-close" @click="activeItem = null">✕</button>
        <h2 style="margin-bottom: var(--space-2)">{{ activeItem.title }}</h2>
        <p v-if="activeItem.description"
           style="color: var(--clr-ink-3); font-size: 0.9rem; margin-bottom: var(--space-4)">
          {{ activeItem.description }}
        </p>

        <div class="item-preview">
          <img v-if="activeItem.thumbnail" :src="activeItem.thumbnail"
               :alt="activeItem.title" style="max-width: 100%; border-radius: var(--radius-md)" />
          <div v-else class="no-thumb-lg">📄</div>
        </div>

        <div class="item-actions">
          <button class="btn btn-ghost btn-sm" @click="download(activeItem)">↓ Download</button>
        </div>

        <hr class="divider" />
        <CommentThread :submissionId="activeItem.id" :comments="activeItem.comments" />
      </div>
    </div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, ref } from "vue";
  import { useRoute } from "vue-router";
  import CommentThread from "../components/CommentThread.vue";

  type Comment = { id: string; author: string; text: string; createdAt: Date }
  type Submission = {
    id: string; title: string; description: string; thumbnail: string | null
    submittedAt: Date; commentCount: number; comments: Array<Comment>
  }

  export default defineComponent({
    name:       "StudentGalleryView"
  , components: { CommentThread }
  , setup() {

      const _ = useRoute();

      const galleryName        = ref("Spring Art Showcase");
      const galleryDescription = ref("Share your artwork from this term's project. All styles welcome!");

      const uploadModalOpen = ref(false);
      const uploadDragging  = ref(false);
      const uploading       = ref(false);
      const uploadError     = ref("");
      const uploadInputRef  = ref<HTMLInputElement | null>(null);
      const activeItem      = ref<      Submission | null>(null);

      const uploadForm = ref({ title: "", description: "", fileName: "", fileData: null as File | null });

      // TODO: Demo submissions
      const submissions =
        ref<Array<Submission>>(
          [ { id:           "1"
            , title:        "Still Life — Fruit Bowl"
            , description:  "Oil pastel on paper."
            , thumbnail:    "https://picsum.photos/seed/art3/400/300"
            , submittedAt:  new Date("2025-04-01")
            , commentCount: 4
            , comments: [
                { id: "c1", author: "Jamie", text:      "I love the colours you chose!", createdAt: new Date("2025-04-02") }
              , { id: "c2", author:   "Sam", text: "Really nice shading on the banana.", createdAt: new Date("2025-04-03") }
            , ]
            }
          , { id:           "2"
            , title:        "Portrait Study"
            , description:  ""
            , thumbnail:    "https://picsum.photos/seed/art4/400/300"
            , submittedAt:  new Date("2025-03-28")
            , commentCount: 2
            , comments:     []
            }
          ]
        );

      function formatDate(d: Date): string {
        return d.toLocaleDateString("en-US", { day: "numeric", month: "short" });
      }

      function openItem(item: Submission): void {
        activeItem.value = item;
      }

      function download(item: Submission): void {
        alert(`Downloading: ${item.title}`);
      }

      function triggerUploadInput(): void {
        uploadInputRef.value?.click();
      }

      function setUploadFile(file: File): void {
        uploadForm.value.fileName = file.name;
        uploadForm.value.fileData = file;
      }

      function onUploadFile(e: Event): void {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (file) {
          setUploadFile(file);
        }
      }

      function onUploadDrop(e: DragEvent): void {
        uploadDragging.value = false;
        const file           = e.dataTransfer?.files[0];
        if (file !== undefined) {
          setUploadFile(file);
        }
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
          submissions.value.unshift({
            id:           Date.now().toString()
          , title:        uploadForm.value.title.trim()
          , description:  uploadForm.value.description
          , thumbnail:    null
          , submittedAt:  new Date()
          , commentCount: 0
          , comments:     []
          });
          uploadForm.value      = { title: "", description: "", fileName: "", fileData: null };
          uploadModalOpen.value = false;
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

      return {
        activeItem, download, formatDate, galleryDescription, galleryName, onUploadDrop, onUploadFile
      , openItem, submissions, submitUpload, triggerUploadInput, uploadDragging, uploadError, uploadForm
      , uploading, uploadInputRef, uploadModalOpen
      };

    }
  });

</script>

<style scoped>

  .student-nav {
    position:                sticky;
    top:                     0;
    z-index:                 100;
    background:              rgba(253,246,238,0.92);
    -webkit-backdrop-filter: blur(12px);
    backdrop-filter:         blur(12px);
    border-bottom:           1px solid var(--clr-border);
    padding:                 0 var(--space-6);
    height:                  60px;
    display:                 flex;
    align-items:             center;
    justify-content:         space-between;
    gap:                     var(--space-4);
  }

  .gallery-title-pill {
    font-family:   var(--font-display);
    font-size:     0.9rem;
    font-weight:   600;
    background:    var(--clr-surface-2);
    border:        1px solid var(--clr-border);
    border-radius: 999px;
    padding:       4px 14px;
    color:         var(--clr-ink-2);
    white-space:   nowrap;
    overflow:      hidden;
    text-overflow: ellipsis;
    max-width:     280px;
  }

  .gallery-hero {
    background:    var(--clr-surface-2);
    border:        1px solid var(--clr-border);
    border-radius: var(--radius-lg);
    padding:       var(--space-5);
    margin-bottom: var(--space-6);
  }

  .gallery-description {
    font-style: italic;
    color:      var(--clr-ink-2);
  }

  .no-thumb {
    font-size:       2rem;
    display:         flex;
    align-items:     center;
    justify-content: center;
    width:           100%;
    height:          100%;
    background:      var(--clr-surface-2);
  }

  .item-detail-modal {
    max-width: 640px;
  }

  .item-preview {
    border-radius: var(--radius-md);
    overflow:      hidden;
    background:    var(--clr-surface-2);
    margin-bottom: var(--space-3);
  }

  .no-thumb-lg {
    width:           100%;
    height:          200px;
    display:         flex;
    align-items:     center;
    justify-content: center;
    font-size:       3rem;
  }

  .item-actions {
    display:       flex;
    gap:           var(--space-3);
    margin-bottom: var(--space-2);
   }

  .modal-footer {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
    margin-top:      var(--space-5);
   }

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
   }

</style>
