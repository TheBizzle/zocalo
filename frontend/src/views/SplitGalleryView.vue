<template>
  <div class="split-page">
    <!-- Compact top bar -->
    <div class="split-topbar">
      <span class="navbar-brand" style="pointer-events: none; font-size: 1.1rem">
        <span class="brand-dot"></span>
        zócalo
      </span>
      <div class="gallery-title-pill">{{ galleryName }}</div>
      <div style="display: flex; gap: var(--space-3)">
        <button class="btn btn-primary btn-sm" @click="uploadModalOpen = true">
          + Upload
        </button>
      </div>
    </div>

    <!-- Main split layout -->
    <div class="split-layout">

      <!-- ─── Left sidebar: submission list ─── -->
      <aside class="split-sidebar">
        <div class="sidebar-header">
          <h3 style="font-size: 0.9rem; color: var(--clr-ink-3); font-weight: 600">
            Submissions
            <span style="font-weight: 400; color: var(--clr-muted)">({{ submissions.length }})</span>
          </h3>
        </div>

        <div v-if="submissions.length === 0" class="sidebar-empty">
          <p>No submissions yet.</p>
        </div>

        <div
          v-for="item in submissions" :key="item.id"
          class="split-sidebar-item"
          :class="{ selected: selectedItem?.id === item.id }"
          @click="selectItem(item)"
        >
          <div class="sidebar-thumb" v-if="item.thumbnail">
            <img :src="item.thumbnail" :alt="item.title" />
          </div>
          <div class="sidebar-thumb no-img" v-else>📄</div>
          <div class="sidebar-info">
            <div class="sidebar-title">{{ item.title }}</div>
            <div class="sidebar-meta">{{ formatDate(item.submittedAt) }}</div>
          </div>
        </div>
      </aside>

      <!-- ─── Right: iframe pane ─── -->
      <main class="split-main">
        <!-- Toolbar above iframe -->
        <div class="split-iframe-toolbar">
          <template v-if="selectedItem">
            <span class="selected-label">
              Viewing: <strong>{{ selectedItem.title }}</strong>
            </span>
            <div style="flex: 1"></div>
            <button class="btn btn-ghost btn-sm" @click="download(selectedItem)">
              ↓ Download
            </button>
            <button class="btn btn-secondary btn-sm" @click="loadIntoIframe">
              Load in viewer →
            </button>
            <button class="btn btn-ghost btn-sm" @click="commentPanelOpen = !commentPanelOpen">
              💬 Comments {{ selectedItem.commentCount > 0 ? `(${selectedItem.commentCount})` : '' }}
            </button>
          </template>
          <template v-else>
            <span style="font-size: 0.875rem; color: var(--clr-muted)">
              Select a submission from the left to view it here.
            </span>
          </template>
        </div>

        <!-- iframe / placeholder -->
        <div class="iframe-area" v-if="iframeSrc">
          <iframe
            :src="iframeSrc"
            :title="selectedItem?.title ?? 'Gallery content'"
            sandbox="allow-scripts allow-same-origin"
          ></iframe>
        </div>
        <div class="iframe-placeholder" v-else>
          <div class="placeholder-inner">
            <p style="font-size: 3rem; margin-bottom: var(--space-4)">🖼️</p>
            <h3>Select a submission</h3>
            <p v-if="!selectedItem">Choose an item from the list on the left.</p>
            <p v-else>Click <strong>Load in viewer</strong> to display it here.</p>
          </div>
        </div>

        <!-- Comment panel — slide in below iframe -->
        <div class="comment-panel" :class="{ open: commentPanelOpen }" v-if="selectedItem">
          <div class="comment-panel-inner">
            <CommentThread :submissionId="selectedItem.id" :comments="selectedItem.comments" />
          </div>
        </div>
      </main>
    </div>

    <!-- ─── Upload modal ─── -->
    <div class="modal-overlay animate-fade" v-if="uploadModalOpen" @click.self="uploadModalOpen = false">
      <div class="modal-box animate-scale">
        <button class="btn-icon modal-close" @click="uploadModalOpen = false">✕</button>
        <p class="section-eyebrow">Share your work</p>
        <h2 style="margin-bottom: var(--space-5)">Upload to gallery</h2>

        <div class="form-stack">
          <div class="form-group">
            <label class="form-label">Title <span class="required">*</span></label>
            <input v-model="uploadForm.title" class="form-input" type="text" />
          </div>
          <div class="form-group">
            <label class="form-label">Description</label>
            <textarea v-model="uploadForm.description" class="form-textarea" rows="2"></textarea>
          </div>
          <div class="form-group">
            <label class="form-label">File <span class="required">*</span></label>
            <div class="file-zone" @click="triggerInput" :class="{ dragover: dragging }"
                 @dragover.prevent="dragging=true" @dragleave="dragging=false" @drop.prevent="onDrop">
              <input ref="fileRef" type="file" style="display: none" @change="onFile" />
              <div v-if="!uploadForm.fileName">
                <p style="font-size: 1.5rem">📎</p>
                <p style="font-size: 0.9rem; color: var(--clr-ink-2)">Click or drag your file here</p>
              </div>
              <p v-else style="font-size: 0.9rem; font-weight: 600; color: var(--clr-accent)">
                ✓ {{ uploadForm.fileName }}
              </p>
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
  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, ref } from "vue";
  import { useRoute                       } from "vue-router";

  import CommentThread from "@/components/student/CommentThread.vue";
  import { setTitle }  from "@/composables/setTitle.ts";

  type Comment = { id: string; author: string; text: string; createdAt: Date }

  type Submission = {
    id:           string;
    title:        string;
    description:  string
    thumbnail:    string | null;
    submittedAt:  Date
    commentCount: number;
    comments:     Array<Comment>
    fileUrl:      string
  }

  export default defineComponent({
    name:       "SplitGalleryView"
  , components: { CommentThread }
  , setup() {

      useRoute();

      const galleryName      = ref("Science Fair Posters");
      const selectedItem     = ref<Submission | null>(null);
      const iframeSrc        = ref("");
      const commentPanelOpen = ref(false);
      const uploadModalOpen  = ref(false);
      const dragging         = ref(false);
      const uploading        = ref(false);
      const fileRef          = ref<HTMLInputElement | null>(null);
      const uploadForm       = ref({ title: "", description: "", fileName: "", fileData: null as File | null });

      const title = computed(() => `${galleryName.value} Gallery`);
      setTitle(title);

      // TODO: Demo data
      const submissions =
        ref<Array<Submission>>(
          [ { id:           "1"
            , title:        "Solar System Model"
            , description:  "A scale diagram."
            , thumbnail:    "https://picsum.photos/seed/sci1/80/60"
            , submittedAt:  new Date("2025-04-05")
            , commentCount: 3
            , comments:     []
            , fileUrl:      "https://example.com/solar.html"
            }
          , { id:           "2"
            , title:        "Photosynthesis Explained"
            , description:  ""
            , thumbnail:    "https://picsum.photos/seed/sci2/80/60"
            , submittedAt:  new Date("2025-04-06")
            , commentCount: 1
            , comments:     []
            , fileUrl:      "https://example.com/photo.html"
            }
         ]);

      function formatDate(d: Date): string {
        return d.toLocaleDateString("en-US", { day: "numeric", month: "short" });
      }

      function selectItem(item: Submission): void {
        selectedItem.value     = item;
        iframeSrc.value        = "";
        commentPanelOpen.value = false;
      }

      function loadIntoIframe(): void {
        if (selectedItem.value) {
          iframeSrc.value = selectedItem.value.fileUrl;
        }
      }

      function download(item: Submission): void {
        alert(`Downloading: ${item.title}`);
      }

      function triggerInput(): void {
        fileRef.value?.click();
      }

      function setFile(file: File): void {
        uploadForm.value.fileName = file.name;
        uploadForm.value.fileData = file;
      }

      function onFile(e: Event): void {
        const f = (e.target as HTMLInputElement).files?.[0];
        if (f !== undefined) {
          setFile(f);
        }
      }

      function onDrop(e: DragEvent): void {
        dragging.value = false;
        const f = e.dataTransfer?.files[0];
        if (f !== undefined) {
          setFile(f);
        }
      }

      async function submitUpload(): Promise<void> {

        if (uploadForm.value.title.trim() === "" || uploadForm.value.fileData === null)
          return;

        uploading.value = true;

        try {

          await new Promise(r => setTimeout(r, 800));

          submissions.value.unshift({
            id:           Date.now().toString()
          , title:        uploadForm.value.title.trim()
          , description:  uploadForm.value.description
          , thumbnail:    null
          , submittedAt:  new Date()
          , commentCount: 0
          , comments:     []
          , fileUrl:      ""
          });

          uploadForm.value      = { title: "", description: "", fileName: "", fileData: null };
          uploadModalOpen.value = false;

        } finally {
          uploading.value = false;
        }

      }

      return {
        commentPanelOpen, download, dragging, fileRef, formatDate, galleryName, iframeSrc, loadIntoIframe
      , onDrop, onFile, selectedItem, selectItem, submissions, submitUpload, triggerInput, uploadForm
      , uploading, uploadModalOpen
      };

    }

  });

</script>

<style scoped>

  .split-page {
    display:        flex;
    flex-direction: column;
    height:         100vh;
    overflow:       hidden;
  }

  .split-topbar {
    height:                  52px;
    flex-shrink:             0;
    background:              rgba(253,246,238,0.95);
    -webkit-backdrop-filter: blur(12px);
    backdrop-filter:         blur(12px);
    border-bottom:           1px solid var(--clr-border);
    padding:                 0 var(--space-5);
    display:                 flex;
    align-items:             center;
    gap:                     var(--space-4);
    z-index:                 50;
  }

  .gallery-title-pill {
    font-family:   var(--font-display);
    font-size:     0.85rem;
    font-weight:   600;
    background:    var(--clr-surface-2);
    border:        1px solid var(--clr-border);
    border-radius: 999px;
    padding:       3px 12px;
    color:         var(--clr-ink-2);
    max-width:     240px;
    white-space:   nowrap;
    overflow:      hidden;
    text-overflow: ellipsis;
  }

  /* Override global split-layout for scoped full-height */
  .split-layout {
    flex:     1;
    overflow: hidden;
  }

  .sidebar-header {
    padding:       var(--space-2) var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--clr-border);
    margin-bottom: var(--space-2);
  }

  .sidebar-empty {
    font-size:  0.875rem;
    color:      var(--clr-muted);
    padding:    var(--space-3);
    text-align: center;
  }

  .split-sidebar-item {
    display:     flex;
    align-items: center;
    gap:         var(--space-3);
  }

  .sidebar-thumb {
    width:         48px;
    height:        36px;
    flex-shrink:   0;
    border-radius: var(--radius-sm);
    overflow:      hidden;
    background:    var(--clr-surface-2);
  }

  .sidebar-thumb img {
    width:      100%;
    height:     100%;
    object-fit: cover;
  }

  .sidebar-thumb.no-img {
    display:         flex;
    align-items:     center;
    justify-content: center;
    font-size:       1rem;
  }

  .sidebar-info {
    min-width: 0;
  }

  .sidebar-title {
    font-size:     0.875rem;
    font-weight:   600;
    color:         var(--clr-ink);
    white-space:   nowrap;
    overflow:      hidden;
    text-overflow: ellipsis;
  }

  .sidebar-meta  {
    font-size: 0.75rem;
    color:     var(--clr-muted);
  }

  .iframe-area {
    flex:     1;
    overflow: hidden;
  }

  .iframe-area iframe {
    width:   100%;
    height:  100%;
    border:  none;
    display: block;
  }

  .iframe-placeholder {
    flex:            1;
    display:         flex;
    align-items:     center;
    justify-content: center;
    background:      var(--clr-surface-2);
  }

  .placeholder-inner {
    text-align: center;
    color:      var(--clr-muted);
  }

  .placeholder-inner h3 {
    color:         var(--clr-ink-3);
    margin-bottom: var(--space-2);
  }

  .placeholder-inner strong {
    color: var(--clr-ink-2);
  }

  .selected-label {
    font-size: 0.875rem;
    color:     var(--clr-ink-2);
  }

  .selected-label strong {
    color: var(--clr-ink);
  }

  .comment-panel {
    max-height: 0;
    overflow:   hidden;
    transition: max-height 300ms ease;
    border-top: 1px solid var(--clr-border);
    background: var(--clr-surface);
  }

  .comment-panel.open {
    max-height: 320px;
    overflow-y: auto;
  }

  .comment-panel-inner {
    padding: var(--space-4) var(--space-5);
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
