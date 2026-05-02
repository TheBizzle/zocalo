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
      <div v-if="hasMounted && sortedGalleries.length > 0" class="high-level-controls">

        <div class="sort-bar">
          <label class="form-label" style="margin: 0 0 0 2px; white-space: nowrap;">Sort by:</label>
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
        <button class="btn btn-primary btn-main" style="margin-top: 16px" @click="openCreateModal">
          Create a gallery
        </button>
      </div>

      <div class="galleries-list stagger" v-else>
        <div
          v-for="gallery in sortedGalleries"
          :key="gallery.id"
          class="gallery-row card animate-fade"
        >
          <div class="card-body">
            <p class="card-title">{{ gallery.name }}</p>
            <p class="card-meta">
              <span>{{ gallery.template }}</span>
              <span class="meta-sep">·</span>
              <span>Created {{ formatDate(gallery.creationTime) }}</span>
              <span class="meta-sep">·</span>
              <span>{{ gallery.numApproved }} uploads</span>
              <template v-if="gallery.numWaiting > 0">
                <span class="meta-sep">·</span>
                <span class="text-warning">{{ gallery.numWaiting }} pending</span>
              </template>
            </p>
            <p v-if="gallery.description" class="card-description">{{ gallery.description }}</p>
          </div>

          <div class="card-footer">
            <div class="footer-actions-left">
              <button class="btn btn-primary" @click="viewAsStudent(gallery)">
                Student view
              </button>
              <button
                v-if="gallery.isPrescreened"
                class="btn btn-accent"
                @click="viewAsTeacher(gallery)"
              >
                Moderation view
              </button>
            </div>
            <button class="btn-text" @click="openCloneModal(gallery)">
              Make another
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
        <h2 style="margin-bottom: var(--space-5)">Make another copy</h2>
        <p style="margin-bottom: var(--space-4); font-size: 0.9rem; color: var(--clr-ink-2)">
          This will create another gallery with the same configuration as
          <strong>{{ cloneSource?.name }}</strong>.  Uploads and comments will <strong>not</strong> be
          copied over.
        </p>

        <div class="alert alert-danger" v-if="cloneError">{{ cloneError }}</div>

        <div class="form-stack">
          <div class="form-group">
            <label class="form-label">New gallery name <span class="required">*</span></label>
            <input v-model="cloneName" class="form-input" type="text" />
          </div>
          <div class="form-group">
            <label class="form-label">Description</label>
            <textarea v-model="cloneDesc" class="form-textarea" rows="3"></textarea>
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

  import { computed, defineComponent, onMounted, ref } from "vue";
  import { useRouter                                 } from "vue-router";

  import CreateGalleryForm                    from "@/components/CreateGalleryForm.vue";
  import { uploadNewGallery                 } from "@/composables/uploadNewGallery.ts";
  import { setTitle                         } from "@/composables/setTitle.ts";
  import { type Gallery, GalleryArraySchema } from "@/core/Gallery.ts";
  import { authorizedFetch, getTeacherID    } from "@/core/TeacherAuth.ts";

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

      const activeTab   = ref<"list" | "create">("list");
      const sortKey     = ref("created_desc");
      const cloneError  = ref<string | null>(null);
      const cloneModal  = ref(false);
      const cloneSource = ref<Gallery | null>(null);
      const cloneName   = ref("");
      const cloneDesc   = ref("");
      const hasMounted  = ref(false);

      const title = computed(() => activeTab.value === "create" ? "Create a Gallery" : "Galleries");
      setTitle(title);

      const sortedGalleries = computed(
        () => {
          const list = [...galleries.value];
          switch (sortKey.value) {
            case "created_desc":
              return list.sort((a, b) => b.creationTime.getTime() - a.creationTime.getTime());
            case "submission_desc":
              return list.sort(
                defaultingToCreationTime(
                  (a, b) => (b.lastSubTime?.getTime() ?? 0) - (a.lastSubTime?.getTime() ?? 0)
                )
              );
            case "name_asc":
              return list.sort(
                defaultingToCreationTime(
                  (a, b) => a.name.localeCompare(b.name)
                )
              );
            case "uploads_desc":
              return list.sort(
                defaultingToCreationTime(
                  (a, b) => b.numApproved - a.numApproved
                )
              );
            case "pending_desc":
              return list.sort(
                defaultingToCreationTime(
                  (a, b) => b.numWaiting - a.numWaiting
                )
              );
            case "template_asc":
              return list.sort(
                defaultingToCreationTime(
                  (a, b) => a.template.localeCompare(b.template)
                )
              );
            default:
              return list;
          }
        }
      );

      function defaultingToCreationTime(f: (a: Gallery, b: Gallery) => number):
          (a: Gallery, b: Gallery) => number {
        return (a: Gallery, b: Gallery) => {
          const result = f(a, b);
          return (result !== 0) ? result : b.creationTime.getTime() - a.creationTime.getTime();
        };
      }

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

      function resetCloneModal(): void {
        cloneError.value = null;
        cloneName.value  = "";
        cloneDesc.value  = "";
      }

      function openCloneModal(g: Gallery): void {
        resetCloneModal();
        cloneSource.value = g;
        cloneModal.value  = true;
      }

      async function confirmClone(): Promise<void> {

        cloneError.value = null;

        const galleryName = cloneName.value.trim();

        if (cloneSource.value === null) {
          cloneError.value = "Impossible to clone nothing.";
          return;
        }

        if (galleryName === "") {
          cloneError.value = "Please enter a gallery name.";
          return;
        }

        const result = await fetch(`api/galleries/public/${getTeacherID()}/${galleryName}/starter-config`);

        if (result.ok) {

          const starterData = await result.text();

          const newGalleryR =
            await uploadNewGallery( galleryName, cloneSource.value.template
                                  , cloneSource.value.isPrescreened, cloneDesc.value
                                  , starterData);

          newGalleryR.fold(
            (error)   => { cloneError.value = error.message; }
          , (gallery) => {
              galleries.value.push(gallery);
              resetCloneModal();
              cloneModal.value = false;
              activeTab.value  = "list";
            }
          );

        } else {
          cloneError.value = await result.text();
        }

      }

      function onGalleryCanceled(): void {
        activeTab.value = "list";
      }

      function onGalleryCreated(gallery: Gallery): void {
        galleries.value.push(gallery);
        activeTab.value = "list";
      }

      return {
        activeTab, cloneDesc, cloneError, cloneModal, cloneName, cloneSource, confirmClone, formatDate
      , hasMounted, onGalleryCanceled, onGalleryCreated, openCloneModal, openCreateModal, sortedGalleries
      , sortKey, viewAsStudent, viewAsTeacher
      };

    }
  });

</script>

<style scoped>

  .page-header {
    margin-bottom: var(--space-6);
  }

  .high-level-controls {
    display:         flex;
    flex-direction:  row;
    align-items:     end;
    justify-content: space-between;
    margin-bottom:   var(--space-2);
  }

  .sort-bar {
    display:     flex;
    align-items: center;
    gap:         var(--space-1);
    flex-wrap:   wrap;
  }

  .sort-select {
    max-width: 260px;
  }

  .galleries-list {
    display:               grid;
    grid-template-columns: repeat(auto-fit, minmax(450px, 1fr));
    gap:                   6px;
  }

  .gallery-row {
    background:     var(--clr-surface);
    border:         0.5px solid var(--clr-border-2);
    border-radius:  var(--radius-md);
    display:        flex;
    flex-direction: column;
    overflow:       hidden;
    padding:        unset;
  }

  .card-body {
    flex-grow: 1;
    padding:   1rem 1.25rem;
  }

  .card-title {
    font-weight: 500;
    font-size:   15px;
    color:       var(--clr-ink);
    margin:      0 0 var(--space-1);
  }

  .card-meta {
    display:   flex;
    flex-wrap: wrap;
    gap:       6px;
    color:     var(--clr-ink-3);
    font-size: 0.82rem;
    margin:    0 0 var(--space-1);
  }

  .card-description {
    font-size:  13px;
    color:      var(--clr-ink-3);
    font-style: italic;
    margin:     0;
  }

  .card-footer {
    border-top:  0.5px solid var(--clr-border-2);
    padding:     10px 1.25rem;
    display:     flex;
    align-items: center;
    gap:         var(--space-2);
    background:  #f7f7f7;
  }

  .footer-actions-left {
    display: flex;
    gap:     var(--space-2);
    flex:    1;
  }

  .btn {
    border:        none;
    border-radius: var(--radius-lg);
    padding:       6px var(--space-4);
    font-size:     13px;
    font-family:   var(--font-body);
    cursor:        pointer;
    white-space:   nowrap;
    transition:    opacity var(--transition);
  }

  .btn-text {
    background:  transparent;
    border:      none;
    color:       var(--clr-primary);
    font-size:   13px;
    font-family: var(--font-body);
    cursor:      pointer;
    padding:     0;
    white-space: nowrap;
    transition:  opacity var(--transition);
  }

  .btn-text:hover {
    color: var(--clr-primary-dk);
  }

  .new-gallery-button {
    font-size:  0.9rem;
    min-height: 2.75rem;
  }

  .meta-sep {
    color: var(--clr-ink);
  }

  .text-warning {
    color:       var(--clr-pending);
    font-weight: 600;
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

  .btn-main {
    font-size: var(--space-5);
    padding:   var(--space-4) var(--space-5);
  }

</style>
