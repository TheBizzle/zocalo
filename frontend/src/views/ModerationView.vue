<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="page-wrapper-wide">

    <div class="mod-header animate-fade">
      <div>
        <p class="section-eyebrow">Moderation</p>
        <h1>{{ galleryName }}</h1>
      </div>
      <div class="mod-header-actions">
        <router-link to="/galleries/teacher/overview" class="btn btn-ghost">
          ← Back to My Galleries
        </router-link>
      </div>
    </div>

    <!-- ─── PENDING pane ─── -->
    <div class="pane animate-fade" style="animation-delay: 60ms">
      <div class="collapsible-header" @click="pendingOpen = !pendingOpen">
        <div class="pane-title">
          <span>Pending submissions</span>
          <span class="badge badge-pending">{{ pendingItems.length }}</span>
        </div>
        <span class="collapsible-arrow" :class="{ open: pendingOpen }">▾</span>
      </div>

      <div class="collapsible-body" v-if="pendingOpen">
        <div v-if="pendingItems.length === 0" class="empty-state" style="padding: var(--space-6)">
          <p style="color: var(--clr-muted)">No pending submissions. 🎉</p>
        </div>
        <div v-else>
          <div
            v-for="item in pendingItems" :key="item.id"
            class="submission-row submission-row-pending"
          >
            <div class="submission-thumb">
              <img v-if="item.thumbnail" :src="item.thumbnail" :alt="item.title" />
              <div v-else class="thumb-placeholder">📄</div>
            </div>
            <div class="submission-info">
              <div class="submission-title">{{ item.title }}</div>
              <div class="submission-meta">
                Submitted {{ formatDate(item.submittedAt) }}
                <template v-if="item.description">
                  · {{ item.description }}
                </template>
              </div>
            </div>
            <div class="submission-actions">
              <button class="btn btn-ghost btn-sm" @click="openPreview(item)">View</button>
              <button class="btn btn-ghost btn-sm" @click="download(item)">↓ Download</button>
              <button class="btn btn-accent btn-sm" @click="approve(item)">✓ Approve</button>
              <button class="btn btn-danger btn-sm" @click="reject(item)">✕ Reject</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ─── APPROVED pane ─── -->
    <div class="pane animate-fade" style="animation-delay: 120ms; margin-top: var(--space-4)">
      <div class="collapsible-header" @click="approvedOpen = !approvedOpen">
        <div class="pane-title">
          <span>Approved submissions</span>
          <span class="badge badge-approved">{{ approvedItems.length }}</span>
        </div>
        <span class="collapsible-arrow" :class="{ open: approvedOpen }">▾</span>
      </div>

      <div class="collapsible-body" v-if="approvedOpen">
        <div v-if="approvedItems.length === 0" class="empty-state" style="padding: var(--space-6)">
          <p style="color: var(--clr-muted)">No approved items yet.</p>
        </div>
        <div v-else>
          <div
            v-for="item in approvedItems" :key="item.id"
            class="submission-row"
          >
            <div class="submission-thumb">
              <img v-if="item.thumbnail" :src="item.thumbnail" :alt="item.title" />
              <div v-else class="thumb-placeholder">📄</div>
            </div>
            <div class="submission-info">
              <div class="submission-title">{{ item.title }}</div>
              <div class="submission-meta">
                Approved {{ formatDate(item.approvedAt) }}
                · {{ item.commentCount }} comment{{ item.commentCount !== 1 ? 's' : '' }}
              </div>
            </div>
            <div class="submission-actions">
              <button class="btn btn-ghost btn-sm" @click="openPreview(item)">View</button>
              <button class="btn btn-ghost btn-sm" @click="download(item)">↓ Download</button>
              <button class="btn btn-danger btn-sm" @click="revoke(item)">Revoke</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ─── Preview modal ─── -->
    <div class="modal-overlay animate-fade" v-if="previewItem" @click.self="previewItem = null">
      <div class="modal-box preview-modal animate-scale">
        <button class="btn-icon modal-close" @click="previewItem = null">✕</button>
        <p class="section-eyebrow">Submission preview</p>
        <h2 style="margin-bottom: var(--space-3)">{{ previewItem.title }}</h2>
        <p v-if="previewItem.description"
           style="font-size: 0.9rem; color: var(--clr-ink-3); margin-bottom: var(--space-4)">
          {{ previewItem.description }}
        </p>
        <div class="preview-area">
          <img v-if="previewItem.thumbnail" :src="previewItem.thumbnail"
               :alt="previewItem.title" style="max-width: 100%; border-radius: var(--radius-md)" />
          <div v-else class="thumb-placeholder"
               style="width: 100%; height: 200px; font-size: 3rem">📄</div>
        </div>
        <div class="modal-footer" style="margin-top: var(--space-5)">
          <button class="btn btn-ghost" @click="download(previewItem)">↓ Download</button>
          <template v-if="previewItem.status === 'pending'">
            <button class="btn btn-danger"
                    @click="reject(previewItem); previewItem = null">Reject</button>
            <button class="btn btn-primary"
                    @click="approve(previewItem); previewItem = null">✓ Approve</button>
          </template>
          <template v-else>
            <button class="btn btn-danger"
                    @click="revoke(previewItem); previewItem = null">Revoke approval</button>
          </template>
        </div>
      </div>
    </div>

  </div>
</template>

<script lang="ts">

  import { defineComponent, ref, computed } from "vue";
  import { useRoute } from "vue-router";

  import { setTitle } from "@/composables/setTitle.ts";

  type SubmissionItem = {
    id:           string
    title:        string
    description:  string
    status:       "pending" | "approved"
    submittedAt:  Date
    approvedAt:   Date | null
    thumbnail:    string | null
    commentCount: number
  }

  export default defineComponent({
    name: "ModerationView"
  , setup() {

      useRoute();

      const galleryName  = ref("Spring Art Showcase"); // TODO: fetch from API using route.params.id
      const pendingOpen  = ref(true);
      const approvedOpen = ref(true);
      const previewItem  = ref<SubmissionItem | null>(null);

      const title = computed(() => `${galleryName.value} - Moderation`);
      setTitle(title);

      // TODO: Demo data
      const items =
        ref<Array<SubmissionItem>>(
          [ { id:           "1"
            , title:        "Watercolour Landscape"
            , description:  "My take on the riverside view."
            , status:       "pending"
            , submittedAt:  new Date("2025-04-10")
            , approvedAt:   null
            , thumbnail:    "https://picsum.photos/seed/art1/120/90"
            , commentCount: 0
            }
          , { id:           "2"
            , title:        "Abstract Composition #3"
            , description:  ""
            , status:       "pending"
            , submittedAt:  new Date("2025-04-09")
            , approvedAt:   null
            , thumbnail:    "https://picsum.photos/seed/art2/120/90"
            , commentCount: 0
            }
          , { id:           "3"
            , title:        "Still Life — Fruit Bowl"
            , description:  "Oil pastel on paper."
            , status:       "approved"
            , submittedAt:  new Date("2025-04-01")
            , approvedAt:   new Date("2025-04-02")
            , thumbnail:    "https://picsum.photos/seed/art3/120/90"
            , commentCount: 4
            }
          , { id:           "4"
            , title:        "Portrait Study"
            , description:  ""
            , status:       "approved"
            , submittedAt:  new Date("2025-03-28")
            , approvedAt:   new Date("2025-03-29")
            , thumbnail:    "https://picsum.photos/seed/art4/120/90"
            , commentCount: 2
            }
          ]
        );

      const pendingItems  = computed(() => items.value.filter(i => i.status ===  "pending"));
      const approvedItems = computed(() => items.value.filter(i => i.status === "approved"));

      function formatDate(d: Date | null): string {
        const dateFormat = { day: "numeric", month: "short", year: "numeric" } as const;
        return (d !== null) ? d.toLocaleDateString("en-US", dateFormat) : "";
      }

      function approve(item: SubmissionItem): void {
        item.status     = "approved";
        item.approvedAt = new Date();
      }

      function reject(item: SubmissionItem): void {
        items.value = items.value.filter(i => i.id !== item.id);
      }

      function revoke(item: SubmissionItem): void {
        item.status     = "pending";
        item.approvedAt = null;
      }

      function download(item: SubmissionItem): void {
        // TODO: trigger actual download via API
        alert(`Downloading: ${item.title}`);
      }

      function openPreview(item: SubmissionItem): void {
        previewItem.value = item;
      }

      return {
        approve, approvedItems, approvedOpen, download, formatDate, galleryName, openPreview
      , pendingItems, pendingOpen, previewItem, reject, revoke
      };

    }
  });

</script>

<style scoped>

  .mod-header {
    display:         flex;
    align-items:     flex-end;
    justify-content: space-between;
    gap:             var(--space-4);
    margin-bottom:   var(--space-6);
    flex-wrap:       wrap;
  }

  .mod-header-actions {
    display: flex;
    gap:     var(--space-3);
  }

  .pane-title {
    display:     flex;
    align-items: center;
    gap:         var(--space-3);
    font-weight: 600;
  }

  .submission-row {
    display:       flex;
    align-items:   center;
    gap:           var(--space-4);
    padding:       var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--clr-border);
    transition:    background var(--transition);
    flex-wrap:     wrap;
  }

  .submission-row:last-child {
    border-bottom: none;
  }

  .submission-row:hover {
    background: var(--clr-surface-2);
  }

  .submission-row-pending {
    border-left: 3px solid var(--clr-pending);
  }

  .submission-thumb {
    width:         64px;
    height:        48px;
    flex-shrink:   0;
    border-radius: var(--radius-sm);
    overflow:      hidden;
    background:    var(--clr-surface-2);
  }

  .submission-thumb img {
    width:      100%;
    height:     100%;
    object-fit: cover;
  }

  .thumb-placeholder {
    width:           100%;
    height:          100%;
    display:         flex;
    align-items:     center;
    justify-content: center;
    font-size:       1.5rem;
    background:      var(--clr-surface-2);
  }

  .submission-info {
    flex:      1;
    min-width: 160px;
  }

  .submission-title {
    font-weight: 600;
    font-size:   0.95rem;
    color:       var(--clr-ink);
  }

  .submission-meta {
    font-size:  0.78rem;
    color:      var(--clr-muted);
    margin-top: 2px;
  }

  .submission-actions {
    display:     flex;
    gap:         var(--space-2);
    flex-wrap:   wrap;
    flex-shrink: 0;
  }

  .preview-modal {
    max-width: 640px;
  }

  .preview-area {
    border-radius: var(--radius-md);
    overflow:      hidden;
    background:    var(--clr-surface-2);
  }

  .modal-footer {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
    flex-wrap:       wrap;
  }

</style>
