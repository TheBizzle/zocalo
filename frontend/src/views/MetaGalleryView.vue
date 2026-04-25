<template>
  <div class="page-wrapper-wide">

    <!-- Page header -->
    <div class="page-header animate-fade">
      <div>
        <h1>Galleries</h1>
      </div>
    </div>

    <div v-if="activeTab === 'list'" class="animate-fade">

      <!-- Sort bar -->
      <div class="high-level-controls">

        <div class="sort-bar">
          <label class="form-label" style="margin: 0; white-space: nowrap;">Sort by:</label>
          <select v-model="sortKey" class="form-select sort-select">
            <option value="created_desc">Latest creation</option>
            <option value="submission_desc">Latest student submission</option>
            <option value="name_asc">Name (A–Z)</option>
            <option value="uploads_desc">Most uploads</option>
            <option value="pending_desc">Most pending</option>
            <option value="template_asc">Template name (A–Z)</option>
          </select>
        </div>

        <button class="btn btn-primary btn-lg new-gallery-button" @click="openCreateModal">
          + New Gallery
        </button>

      </div>

      <div v-if="hasMounted && sortedGalleries.length === 0" class="empty-state">
        <div class="empty-state-icon">🖼️</div>
        <h3>No galleries yet</h3>
        <p>Create your first gallery to get started.</p>
        <button class="btn btn-primary" style="margin-top: 16px" @click="openCreateModal">
          Create a gallery
        </button>
      </div>

      <div class="galleries-list stagger" v-else>
        <div
          v-for="gallery in sortedGalleries"
          :key="gallery.id"
          class="gallery-row card animate-fade"
          :class="{ selected: selectedGallery?.id === gallery.id }"
          @click="selectedGallery = gallery"
        >
          <div class="gallery-row-main">
            <div class="gallery-row-title">
              <span class="display">{{ gallery.name }}</span>
              <span class="badge" :class="gallery.isModerated ? 'badge-moderated' : 'badge-open'">
                {{ gallery.isModerated ? 'Moderated' : 'Open' }}
              </span>
            </div>
            <div class="gallery-row-meta">
              <span>{{ gallery.template }}</span>
              <span class="meta-sep">·</span>
              <span>Created {{ formatDate(gallery.createdAt) }}</span>
              <span class="meta-sep">·</span>
              <span>{{ gallery.uploadCount }} uploads</span>
              <template v-if="gallery.pendingCount > 0">
                <span class="meta-sep">·</span>
                <span class="text-warning">{{ gallery.pendingCount }} pending</span>
              </template>
            </div>
            <p v-if="gallery.description" class="gallery-row-desc">{{ gallery.description }}</p>
          </div>

          <div class="gallery-row-actions" @click.stop>
            <button class="btn btn-ghost btn-sm" @click="viewAsStudent(gallery)">
              👁 Student view
            </button>
            <button class="btn btn-accent btn-sm" @click="viewAsTeacher(gallery)">
              🎓 Moderator
            </button>
            <button class="btn btn-secondary btn-sm" @click="openCloneModal(gallery)">
              ⊕ Make another
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="activeTab === 'create'" class="animate-fade">
      <CreateGalleryForm @canceled="onGalleryCanceled" @created="onGalleryCreated" />
    </div>

    <!-- ─── Clone modal ─── -->
    <div class="modal-overlay animate-fade" v-if="cloneModal" @click.self="cloneModal = false">
      <div class="modal-box animate-scale">
        <button class="btn-icon modal-close" @click="cloneModal = false">✕</button>
        <p class="section-eyebrow">Duplicate gallery</p>
        <h2 style="margin-bottom: var(--space-5)">Make another copy</h2>
        <p style="margin-bottom: var(--space-4); font-size: 0.9rem; color: var(--clr-ink-2)">
          This will create a new gallery identical to
          <strong>{{ cloneSource?.name }}</strong>, with a different name and optional description.
        </p>
        <div class="form-stack">
          <div class="form-group">
            <label class="form-label">New gallery name <span class="required">*</span></label>
            <input v-model="cloneForm.name" class="form-input" type="text" placeholder="My Gallery #2" />
          </div>
          <div class="form-group">
            <label class="form-label">Description</label>
            <textarea v-model="cloneForm.description" class="form-textarea"
                      placeholder="Notes for your future self…" rows="3"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="cloneModal = false">Cancel</button>
          <button class="btn btn-primary" @click="confirmClone">Create copy</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, onMounted, reactive, ref } from "vue";
  import { useRouter                                           } from "vue-router";

  import CreateGalleryForm from "@/components/CreateGalleryForm.vue";

  import { GalleryArraySchema } from "@/core/Gallery.ts";
  import { authorizedFetch    } from "@/core/TeacherAuth.ts";

  import type { Gallery } from "@/core/Gallery.ts";

  export default defineComponent({
    name:       "MetaGalleryView"
  , components: { CreateGalleryForm }

  , setup() {

      const router = useRouter();

      const galleries = ref<Array<Gallery>>([]);
      onMounted(
        async () => {
          await updateGalleries();
          hasMounted.value = true;
        }
      );

      const activeTab       = ref<"list" | "create">("list");
      const sortKey         = ref("created_desc");
      const selectedGallery = ref<Gallery | null>(null);
      const cloneModal      = ref(false);
      const cloneSource     = ref<Gallery | null>(null);
      const cloneForm       = reactive({ name: "", description: "" });
      const hasMounted      = ref(false);

      const sortedGalleries = computed(
        () => {
          const list = [...galleries.value];
          switch (sortKey.value) {
            case "created_desc":
              return list.sort((a, b) => b.creationTime.getTime() - a.creationTime.getTime());
            case "submission_desc":
              return list.sort(
                (a, b) => (b.lastSubTime?.getTime() ?? 0) - (a.lastSubTime?.getTime() ?? 0)
              );
            case "name_asc":
              return list.sort((a, b) => a.name.localeCompare(b.name));
            case "uploads_desc":
              return list.sort(
                (a, b) => b.numApproved - a.numApproved
              );
            case "pending_desc":
              return list.sort(
                (a, b) => b.numWaiting - a.numWaiting
              );
            case "template_asc":
              return list.sort((a, b) => a.template.localeCompare(b.template));
            default:
              return list;
          }
        }
      );

      async function updateGalleries(): Promise<void> {
        const result  = await authorizedFetch("/api/galleries/teacher/overview");
        if (result.ok) {
          galleries.value = GalleryArraySchema.parse(await result.json());
        } else {
          const message = await result.text();
          throw new Error(message);
        }
      }

      function formatDate(d: Date): string {
        return d.toLocaleDateString("en-US", { day: "numeric", month: "short", year: "numeric" });
      }

      function openCreateModal(): void {
        activeTab.value = "create";
      }

      function viewAsTeacher(g: Gallery): void {
        void router.push(`/moderate/${g.id}`);
      }

      function viewAsStudent(g: Gallery): void {
        void router.push(`/gallery/${g.id}`);
      }

      function openCloneModal(g: Gallery): void {
        cloneSource.value     = g;
        cloneForm.name        = "";
        cloneForm.description = "";
        cloneModal.value      = true;
      }

      function confirmClone(): void {

        // TODO: API call to clone gallery
        const newGallery: Gallery = {
          ...(cloneSource.value as Gallery)
        , id:           Date.now()
        , name:         cloneForm.name.trim()
        , description:  cloneForm.description
        , numApproved:  0
        , numWaiting:   0
        , creationTime: new Date()
        , lastSubTime:  null,
        };

        galleries.value.push(newGallery);

        cloneModal.value = false;
        activeTab.value  = "list";

      }

      function onGalleryCanceled(): void {
        activeTab.value = "list";
      }

      function onGalleryCreated(gallery: Gallery): void {
        galleries.value.push(gallery);
        activeTab.value = "list";
      }

      return {
        activeTab, cloneForm, cloneModal, cloneSource, confirmClone, formatDate, hasMounted
      , onGalleryCanceled, onGalleryCreated, openCloneModal, openCreateModal, sortedGalleries, sortKey
      , viewAsStudent, viewAsTeacher
      };

    }
  });

</script>

<style scoped>

  .page-header {
    margin-bottom: var(--space-6);
  }

  .high-level-controls {
    align-items:     center;
    display:         flex;
    flex-direction:  row;
    justify-content: space-between;
  }

  .new-gallery-button {
    max-height: 3.5rem;
  }

  .sort-bar {
    display:       flex;
    align-items:   center;
    gap:           var(--space-1);
    margin-bottom: var(--space-3);
    flex-wrap:     wrap;
  }

  .sort-select {
    max-width: 260px;
  }

  .galleries-list {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
  }

  .gallery-row {
    display:         flex;
    align-items:     flex-start;
    justify-content: space-between;
    gap:             var(--space-5);
    cursor:          pointer;
    flex-wrap:       wrap;
  }

  .gallery-row.selected {
    border-color: var(--clr-primary);
    box-shadow:   0 0 0 3px var(--clr-primary-lt);
  }

  .gallery-row-main {
    flex:      1;
    min-width: 0;
  }

  .gallery-row-title {
    display:       flex;
    align-items:   center;
    gap:           var(--space-3);
    font-size:     1.15rem;
    font-weight:   600;
    margin-bottom: var(--space-2);
    flex-wrap:     wrap;
  }

  .gallery-row-meta {
    font-size: 0.82rem;
    color:     var(--clr-ink-3);
    display:   flex;
    flex-wrap: wrap;
    gap:       4px;
  }

  .meta-sep {
    color: var(--clr-border-2);
  }

  .text-warning {
    color:       var(--clr-pending);
    font-weight: 600;
  }

  .gallery-row-desc {
    font-size:  0.875rem;
    color:      var(--clr-ink-3);
    margin-top: var(--space-2);
    font-style: italic;
  }

  .gallery-row-actions {
    display:     flex;
    gap:         var(--space-2);
    flex-wrap:   wrap;
    flex-shrink: 0;
    align-items: flex-start;
  }

  .modal-footer {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
    margin-top:      var(--space-6);
  }

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
  }

</style>
