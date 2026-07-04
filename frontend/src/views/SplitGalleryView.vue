<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="split-page">

    <VerticalSplit>

      <template #aside>

        <h3 class="sidebar-heading">
          <div class="gallery-title" :title="galleryName">
            {{ galleryName }}
          </div>
        </h3>

        <div v-if="submissions.length === 0" class="sidebar-empty">
          <p>No submissions yet.</p>
        </div>

        <div v-else class="item-list">
          <div
            v-for="item in submissions" :key="item.id"
            class="split-sidebar-item item"
            :class="{ selected: activeSubmission?.id === item.id }"
            @click="setActiveSubmission(item)"
          >
            <div class="sidebar-thumb" v-if="item.image !== null">
              <img :src="item.image" :alt="item.uploader" />
            </div>
            <div class="sidebar-thumb no-img" v-else>📄</div>
            <div class="sidebar-info">
              <div class="sidebar-title">{{ item.uploader }}</div>
            </div>
          </div>
        </div>

        <div class="controls-container">

          <a v-if="extStartURL !== null && activity.starterMode === 'external'" :href="extStartURL.href"
             class="btn btn-accent btn-lg doc-button floaty" target="_blank" rel="noopener noreferrer">
            📑 Open starter sheet
          </a>

          <button class="btn btn-primary btn-lg floaty share-button" @click="isUploadModalOpen = true">
            ✚ Share your own
          </button>

        </div>

      </template>

      <template #main>

        <SubmissionDetailModal
          :activity="activity"
          :galleryID="galleryID"
          :isSplit="true"
          :submission="activeSubmission"
          @add-comment="addComment"
          @load-in-split="loadInSplit"
          @unset-active-submission="unsetActiveSubmission"
        />

        <UploadModal
          :activity="activity"
          :exportData="exportedData"
          :isOpen="isUploadModalOpen"
          @add-new-submission="addNewSubmission"
          @close-dialog="isUploadModalOpen = false"
        />

        <div class="split-frame-toolbar filled-when-empty">
          <h3 v-if="loadedAuthor !== null" class="active-title">
            <span class="active-label">Shared by</span>
            <span class="active-filler">: </span>
            <span class="active-author">{{ loadedAuthor }}</span>
          </h3>
        </div>

        <div v-if="loadedContent === null && isShowingFiller" class="frame-placeholder">
          <div class="placeholder-inner">
            <p style="font-size: 3rem; margin-bottom: var(--space-4)">🖼️</p>
            <h3>View submitted work</h3>
            <p v-if="!activeSubmission">
              Choose an item from the list on the left and then click <strong>Load</strong>
              to display it here.
            </p>
          </div>
        </div>

        <Geogebra v-if="activity.name === 'geogebra'" @export-data="storeData" @hide-filler="hideFiller"
                  :galleryID="galleryID" :loadedContent="loadedContent ?? ''"
                  :shouldExport="isUploadModalOpen" />

        <GoogleDocsRenderer v-else-if="activity.name === 'google-docs'"
                            @external-starter-url="onExternalStarter"
                            :galleryID="galleryID" :loadedContent="loadedContent ?? ''" />

        <NetLogo v-else-if="activity.name === 'netlogo'"
                 @export-data="storeData" @hide-filler="hideFiller"
                 :galleryID="galleryID" :loadedContent="loadedContent ?? ''"
                 :shouldExport="isUploadModalOpen" />

        <NetLogoWithWorld v-else-if="activity.name === 'netlogo-world'"
                          @export-data="storeData" @hide-filler="hideFiller"
                          :galleryID="galleryID" :loadedContent="loadedContent ?? ''"
                          :shouldExport="isUploadModalOpen" />

        <Segregation v-else-if="activity.name === 'segregation'"
                     @export-data="storeData" @hide-filler="hideFiller"
                     :galleryID="galleryID" :loadedContent="loadedContent ?? ''"
                     :shouldExport="isUploadModalOpen" />

        <SweepingArea v-else-if="activity.name === 'sweeping-area'"
                      @export-data="storeData" @hide-filler="hideFiller"
                      :galleryID="galleryID" :loadedContent="loadedContent ?? ''"
                      :shouldExport="isUploadModalOpen" />

      </template>

    </VerticalSplit>

  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, onMounted, type PropType, ref } from "vue";
  import { useRoute                                                 } from "vue-router";

  import Geogebra           from "@/components/Geogebra.vue";
  import GoogleDocsRenderer from "@/components/GoogleDocsRenderer.vue";
  import NetLogo            from "@/components/NetLogo.vue";
  import NetLogoWithWorld   from "@/components/NetLogoWithWorld.vue";
  import Segregation        from "@/components/Segregation.vue";
  import SweepingArea       from "@/components/SweepingArea.vue";
  import VerticalSplit      from "@/components/VerticalSplit.vue";

  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";

  import type { Activity                                       } from "@/core/Activity.ts";
  import type { ExportData                                     } from "@/core/ExportData.ts";
  import { setTitle                                            } from "@/core/setTitle.ts";
  import { authorizedFetch                                     } from "@/core/StudentAuth.ts";
  import { AllSubmissionsSchema, type Comment, type Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:       "SplitGalleryView"
  , components: { Geogebra, GoogleDocsRenderer, NetLogo, NetLogoWithWorld, Segregation, SweepingArea
                , SubmissionDetailModal, UploadModal, VerticalSplit }
  , props:      { activity: { type: Object as PropType<Activity>, required: true } }
  , setup() {

      const route = useRoute();

      const activeSubmission  = ref<Submission | null>(null);
      const extStartURL       = ref<URL | null>(null);
      const exportedData      = ref<ExportData | null>(null);
      const galleryID         = ref<string>(route.params["nanoid"] as string);
      const galleryName       = ref("");
      const isModerated       = ref(true);
      const isShowingFiller   = ref(true);
      const isUploadModalOpen = ref(false);
      const hasMounted        = ref(false);
      const loadedAuthor      = ref<string | null>(null);
      const loadedContent     = ref<string | null>(null);

      const submissions = ref<Array<Submission>>([]);
      onMounted(
        async () => {
          await updateSubmissions();
          hasMounted.value = true;
        }
      );

      function addComment(comment: Comment): void {
        if (activeSubmission.value !== null) {
          activeSubmission.value.comments.push(comment);
        }
      }

      function addNewSubmission(sub: Submission): void {
        if (!isModerated.value) {
          submissions.value.unshift(sub);
        }
      }

      function onExternalStarter(url: string): void {
        extStartURL.value = new URL(url);
      }

      function hideFiller(): void {
        isShowingFiller.value = false;
      }

      async function loadInSplit(submission: Submission): Promise<void> {
        const res = await fetch(`/api/galleries/${galleryID.value}/student/${submission.id}`);
        if (!res.ok) {
          const message = await res.text();
          alert(`Could not load item: ${message}`);
        } else {
          loadedContent.value = await res.text();
          loadedAuthor.value  = submission.uploader;
        }
      }

      function storeData(data: ExportData): void {
        exportedData.value = data;
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

      return { activeSubmission, addComment, addNewSubmission, exportedData, extStartURL, galleryID
             , galleryName, hideFiller, isShowingFiller, isUploadModalOpen, loadedAuthor, loadedContent
             , loadInSplit, onExternalStarter, setActiveSubmission, storeData, submissions
             , unsetActiveSubmission
             };

    }

  });

</script>

<style scoped>

  .active-author {
    font-weight: 700;
  }

  .active-filler {
    font-weight: 100;
  }

  .active-label {
    font-weight: 100;
  }

  .active-title {
    font-size: 1.1rem;
    margin:    4px auto;
  }

  .controls-container {

    display:        flex;
    flex-direction: column;
    gap:            5px;

    position:       absolute;
    bottom:         10px;
    left:           10px;
    z-index:        60;

  }

  .doc-button:hover {
    color: #ffffff;
  }

  .filled-when-empty:empty::before {
    content: "\00a0"; /* NBSP */
    margin:  2px 0;
  }

  .floaty {
    filter: drop-shadow(4px 4px 1px rgba(0, 0, 0, 0.5));
  }

  .frame-placeholder {
    flex:            1;
    display:         flex;
    align-items:     center;
    justify-content: center;
    background:      var(--clr-surface-2);
  }

  .gallery-title {
    font-size:     1.3rem;
    font-weight:   bold;
    margin:        2px auto;
    overflow:      hidden;
    text-overflow: ellipsis;
    white-space:   nowrap;
  }

  .item {
    display:        flex;
    flex-direction: column;
  }

  .item-list {
    display:        flex;
    flex-direction: column;
    gap:            3px;
    padding:        5px;
    overflow-y:     auto;
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
    background:    var(--clr-surface-2);
    border-radius: var(--radius-sm);
    flex-shrink:   0;
    object-fit:    contain;
    overflow:      hidden;
    width:         100%;
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
    font-size:     1.2rem;
    font-weight:   600;
    color:         var(--clr-ink);
    white-space:   nowrap;
    overflow:      hidden;
    text-overflow: ellipsis;
  }

  .split-page {
    display:        flex;
    flex-direction: column;
    height:         93vh;
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
