<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="split-page">

    <div class="split-topbar">
      <span class="navbar-brand" style="pointer-events: none; font-size: 1.1rem">
        <span class="brand-dot"></span>
        zócalo
      </span>
      <div class="gallery-title-pill">{{ galleryName }}</div>
      <div v-if="loadedTitle !== null" class="active-title">
        {{ loadedTitle }}
      </div>
    </div>

    <VerticalSplit>

      <template #aside>

        <h3 class="sidebar-heading">
          Gallery
        </h3>

        <div v-if="submissions.length === 0" class="sidebar-empty">
          <p>No submissions yet.</p>
        </div>

        <div v-else class="item-list">
          <div
            v-for="item in submissions" :key="item.id"
            class="split-sidebar-item"
            :class="{ selected: activeSubmission?.id === item.id }"
            @click="setActiveSubmission(item)"
          >
            <div class="sidebar-thumb" v-if="item.image">
              <img :src="item.image" :alt="item.uploadName" />
            </div>
            <div class="sidebar-thumb no-img" v-else>📄</div>
            <div class="sidebar-info">
              <div class="sidebar-title">[{{ item.uploader }}] {{ item.uploadName }}</div>
            </div>
          </div>
        </div>

        <button class="btn btn-primary btn-lg share-button" @click="isUploadModalOpen = true">
          ✚ Share your own
        </button>

      </template>

      <template #main>

        <SubmissionDetailModal
          :galleryID="galleryID"
          :isSplit="true"
          :submission="activeSubmission"
          @load-in-split="loadInSplit"
          @unset-active-submission="unsetActiveSubmission"
        />

        <UploadModal
          :isOpen="isUploadModalOpen"
          :isText="true"
          @add-new-submission="addNewSubmission"
          @close-dialog="isUploadModalOpen = false"
        />

        <div class="split-frame-toolbar">
          <a v-if="docURL !== null" :href="docURL.href" class="btn btn-primary btn-sm doc-button"
             target="_blank" rel="noopener noreferrer">
            📑 Open starter sheet
          </a>
        </div>

        <div v-if="loadedContent === null" class="frame-placeholder">
          <div class="placeholder-inner">
            <p style="font-size: 3rem; margin-bottom: var(--space-4)">🖼️</p>
            <h3>View submitted work</h3>
            <p v-if="!activeSubmission">
              Choose an item from the list on the left and then click <strong>Load</strong>
              to display it here.
            </p>
          </div>
        </div>
        <GoogleDocsRenderer :loadedContent="loadedContent ?? ''" />

      </template>

    </VerticalSplit>

  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, onMounted, ref } from "vue";
  import { useRoute                                  } from "vue-router";

  import GoogleDocsRenderer    from "@/components/GoogleDocsRenderer.vue";
  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";
  import VerticalSplit         from "@/components/VerticalSplit.vue";

  import { setTitle                              } from "@/core/setTitle.ts";
  import { authorizedFetch                       } from "@/core/StudentAuth.ts";
  import { AllSubmissionsSchema, type Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:       "SplitGalleryView"
  , components: { GoogleDocsRenderer, SubmissionDetailModal, UploadModal, VerticalSplit }
  , setup() {

      const route = useRoute();

      const activeSubmission  = ref<Submission | null>(null);
      const docURL            = ref<URL | null>(null);
      const galleryID         = ref<string>(route.params["nanoid"] as string);
      const galleryName       = ref("");
      const isModerated       = ref(true);
      const isUploadModalOpen = ref(false);
      const hasMounted        = ref(false);
      const loadedContent     = ref<string | null>(null);
      const loadedTitle       = ref<string | null>(null);

      const submissions = ref<Array<Submission>>([]);
      onMounted(
        async () => {
          await updateSubmissions();
          await fetchStarterURL();
          hasMounted.value = true;
        }
      );

      function addNewSubmission(sub: Submission): void {
        if (!isModerated.value) {
          submissions.value.unshift(sub);
        }
      }

      async function fetchStarterURL(): Promise<void> {
        const res = await fetch(`/api/galleries/${galleryID.value}/student/starter-config`);
        if (!res.ok) {
          const message = await res.text();
          alert(`Could not fetch starter: ${message}`);
        } else {
          docURL.value = new URL(await res.text());
        }
      }

      async function loadInSplit(submission: Submission): Promise<void> {
        const res = await fetch(`/api/galleries/${galleryID.value}/student/${submission.uploadName}`);
        if (!res.ok) {
          const message = await res.text();
          alert(`Could not load item: ${message}`);
        } else {
          loadedContent.value = await res.text();
          loadedTitle.value   = `[${submission.uploader}] ${submission.uploadName}`;
        }
      }

      function setActiveSubmission(sub: Submission): void {
        activeSubmission.value = sub;
      }

      function unsetActiveSubmission(): void {
        activeSubmission.value = null;
      }

      async function updateSubmissions(): Promise<void> {

        const result = await authorizedFetch(`/api/galleries/${galleryID.value}/student/submissions`);

        if (result.ok) {

          const subs  = AllSubmissionsSchema.parse(await result.json());
          const asNum = (x: { creationTime: Date }): number => x.creationTime.getTime();
          subs.submissions.forEach((s) => s.comments.sort((x, y) => asNum(x) - asNum(y)));

          submissions.value = subs.submissions.sort((x, y) => asNum(y) - asNum(x));
          isModerated.value = subs.isModerated;
          galleryName.value = subs.galleryName;

        } else {
          alert(await result.text());
        }

      }

      const title = computed(() => `${galleryName.value} Gallery`);
      setTitle(title);

      return { activeSubmission, addNewSubmission, docURL, galleryID, galleryName, isUploadModalOpen
             , loadedContent, loadedTitle, loadInSplit, setActiveSubmission, submissions
             , unsetActiveSubmission
             };

    }

  });

</script>

<style scoped>

  .active-title {
    font-size:   1.3rem;
    font-weight: bold;
    margin:      0 auto;
  }

  .doc-button {
    color:     white;
    font-size: 0.85rem;
  }

  .frame-placeholder {
    flex:            1;
    display:         flex;
    align-items:     center;
    justify-content: center;
    background:      var(--clr-surface-2);
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

  .item-list {
    display:        flex;
    flex-direction: column;
    gap:            3px;
    padding:        5px;
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

  .share-button {
    position: absolute;
    bottom:   10px;
    left:     10px;
    z-index:  10;
  }

  .sidebar-empty {
    font-size:  0.875rem;
    color:      var(--clr-muted);
    padding:    var(--space-3);
    text-align: center;
  }

  .sidebar-heading {
    border-bottom: 1px solid var(--clr-border-2);
    padding:       12px;
    text-align:    center;
  }

  .sidebar-info {
    min-width: 0;
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

  .sidebar-title {
    font-size:     0.875rem;
    font-weight:   600;
    color:         var(--clr-ink);
    white-space:   nowrap;
    overflow:      hidden;
    text-overflow: ellipsis;
  }

  .split-page {
    display:        flex;
    flex-direction: column;
    height:         100vh;
    overflow:       hidden;
  }

  .split-sidebar-item {
    display:     flex;
    align-items: center;
    gap:         var(--space-3);
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

</style>
