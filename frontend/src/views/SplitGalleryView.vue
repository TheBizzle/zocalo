<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="split-page">

    <VerticalSplit>

      <template #aside>

        <h3 class="sidebar-heading">

          <div class="gallery-title" :title="galleryName">
            {{ galleryName }}
          </div>

          <div v-if="isModerating" class="moderation-tabs">
            <div class="unapproved tab-button" :class="{ selected: modTab === 'unapproved' }"
                 @click="selectModTab('unapproved')">
              Pending: {{ waitingSubmissions.length }}
            </div>
            <div class="approved tab-button" :class="{ selected: modTab === 'approved' }"
                 @click="selectModTab('approved')">
              Approved: {{submissions.length}}
            </div>
          </div>

        </h3>

        <div v-if="modTab === 'unapproved'">

          <div v-if="waitingSubmissions.length === 0" class="sidebar-empty">
            <p>No submissions waiting...</p>
          </div>

          <div v-else class="item-list">
            <div
              v-for="item in waitingSubmissions" :key="item.id"
              class="split-sidebar-item item"
              :class="{ selected: activeSubmission?.id === item.id }"
              @click="setActiveSubmission(item)"
            >
              <div class="sidebar-thumb" v-if="item.image !== null">
                <button v-if="item.canModerate" class="thumb-action" @click.stop="rejectSubmission(item)">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
                       stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/>
                    <path d="M19 6l-1 14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1L5 6"/>
                    <line x1="10" y1="11" x2="10" y2="17"/>
                    <line x1="14" y1="11" x2="14" y2="17"/>
                  </svg>
                </button>
                <button v-if="item.canModerate"
                        class="thumb-action" style="background-color: forestgreen; right: 33px;"
                        @click.stop="approveSubmission(item)">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#fff" stroke-width="2.5"
                       stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M3 12.5l5.5 5.5L21 5.5"/>
                  </svg>
                </button>
                <img :src="item.image" :alt="item.uploader" />
              </div>
              <div class="sidebar-thumb no-img" v-else>📄</div>
              <div class="sidebar-info">
                <div class="sidebar-title">{{ item.uploader }}</div>
              </div>
            </div>
          </div>

        </div>

        <div v-if="modTab === 'approved'">

          <div v-if="submissions.length === 0" class="sidebar-empty">
            <p>No submissions yet...</p>
          </div>

          <div v-else class="item-list">
            <div
              v-for="item in submissions" :key="item.id"
              class="split-sidebar-item item"
              :class="{ selected: activeSubmission?.id === item.id }"
              @click="setActiveSubmission(item)"
            >
              <div class="sidebar-thumb" v-if="item.image !== null">
                <button v-if="item.canModerate" class="thumb-action" @click.stop="deleteSubmission(item)">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
                       stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/>
                    <path d="M19 6l-1 14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1L5 6"/>
                    <line x1="10" y1="11" x2="10" y2="17"/>
                    <line x1="14" y1="11" x2="14" y2="17"/>
                  </svg>
                </button>
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

        <NetsBlox v-else-if="activity.name === 'netsblox'"
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
  import { z                                                        } from "zod";

  import Geogebra           from "@/components/Geogebra.vue";
  import GoogleDocsRenderer from "@/components/GoogleDocsRenderer.vue";
  import NetLogo            from "@/components/NetLogo.vue";
  import NetLogoWithWorld   from "@/components/NetLogoWithWorld.vue";
  import NetsBlox           from "@/components/NetsBlox.vue";
  import Segregation        from "@/components/Segregation.vue";
  import SweepingArea       from "@/components/SweepingArea.vue";
  import VerticalSplit      from "@/components/VerticalSplit.vue";

  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";

  import type { Activity                                                         } from "@/core/Activity.ts";
  import type { ExportData                                                       } from "@/core/ExportData.ts";
  import { setTitle                                                              } from "@/core/setTitle.ts";
  import { authorizedFetch as fetchAsTeacher, getAuthToken                       } from "@/core/TeacherAuth.ts";
  import { authorizedFetch as fetchAsStudent                                     } from "@/core/StudentAuth.ts";
  import { AllSubmissionsSchema, type Comment, type Submission, SubmissionSchema }  from "@/core/Submission.ts";

  export default defineComponent({
    name:       "SplitGalleryView"
  , components: { Geogebra, GoogleDocsRenderer, NetLogo, NetLogoWithWorld, NetsBlox, Segregation, SweepingArea
                , SubmissionDetailModal, UploadModal, VerticalSplit }
  , props:      { activity:     { type: Object as PropType<Activity>, required: true }
                , isModerating: { type:                      Boolean, required: true }
                }
  , setup(props) {

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

      const modTab = ref<"unapproved" | "approved">("approved");
      selectModTab("approved");

      const submissions        = ref<Array<Submission>>([]);
      const waitingSubmissions = ref<Array<Submission>>([]);
      onMounted(
        async () => {
          await updateSubmissions();
          if (props.isModerating) {
            await setUpWebSocket();
          }
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

      async function setUpWebSocket(): Promise<void> {

        const protocol = window.location.protocol === "https:" ? "wss" : "ws";
        const domain   = window.location.host;
        const prefix   = `${protocol}://${domain}`;

        const jwt = encodeURIComponent(await getAuthToken() ?? "");

        const socket = new WebSocket(`${prefix}/api/galleries/${galleryID.value}/teacher/moderable/${jwt}`);

        socket.onmessage = (event: MessageEvent<string>): void => {
          const ErrorOrSubs = z.union([z.object({ error: z.string(), }), z.array(SubmissionSchema)]);
          const message     = ErrorOrSubs.parse(JSON.parse(event.data));
          if ("error" in message) {
            console.error(message.error);
          } else {
            waitingSubmissions.value = waitingSubmissions.value.concat(message);
          }
        };

        socket.onerror = (event): void => {
          console.error("Socket error", event);
        };

        socket.onclose = (event): void => {
          console.warn("Socket unexpected closed", event.code, event.reason);
        };

      }

      function storeData(data: ExportData): void {
        exportedData.value = data;
      }

      function selectModTab(typ: "unapproved" | "approved"): void {
        modTab.value = typ;
      }

      function setActiveSubmission(sub: Submission): void {
        activeSubmission.value = sub;
      }

      function unsetActiveSubmission(): void {
        activeSubmission.value = null;
      }

      async function approveSubmission(sub: Submission): Promise<void> {
        const url    = `/api/galleries/${galleryID.value}/teacher/${sub.id}/approve`;
        const result = await fetchAsTeacher(url, { method: "POST" });
        if (result.ok) {
          submissions.value.push(sub);
          waitingSubmissions.value = waitingSubmissions.value.filter((x) => x !== sub);
        } else {
          alert(await result.text());
        }
      }

      async function deleteSubmission(sub: Submission): Promise<void> {

        if (props.isModerating) {
          await rejectSubmission(sub);
        } else if (confirm("Are you sure you want to delete your work?")) {

          const opts   = { method: "DELETE" };
          const result = await fetchAsStudent(`/api/galleries/${galleryID.value}/student/${sub.id}`, opts);

          if (result.ok) {
            submissions.value = submissions.value.filter((x) => x !== sub);
          } else {
            alert(await result.text());
          }

        }

      }

      async function rejectSubmission(sub: Submission): Promise<void> {
        if (confirm(`Are you sure you want to delete ${sub.uploader}'s work?`)) {
          const url    = `/api/galleries/${galleryID.value}/teacher/${sub.id}/reject`;
          const result = await fetchAsTeacher(url, { method: "POST" });
          if (result.ok) {
            waitingSubmissions.value = waitingSubmissions.value.filter((x) => x !== sub);
                   submissions.value =        submissions.value.filter((x) => x !== sub);
          } else {
            alert(await result.text());
          }
        }
      }

      async function updateSubmissions(): Promise<void> {

        const result = await fetchAsStudent(`/api/galleries/${galleryID.value}/student/submissions`);

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

      return { activeSubmission, addComment, addNewSubmission, approveSubmission, deleteSubmission
             , exportedData, extStartURL, galleryID, galleryName, hideFiller, isShowingFiller
             , isUploadModalOpen, loadedAuthor, loadedContent, loadInSplit, modTab, onExternalStarter
             , rejectSubmission, selectModTab, setActiveSubmission, storeData, submissions
             , unsetActiveSubmission, waitingSubmissions
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

  .approved.tab-button {
    background-color: navy;
  }

  .approved.tab-button.selected {
    background-color: blue;
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

  .moderation-tabs {
    display:        flex;
    flex-direction: row;
    font-size:      14px;
    max-height:     41px;
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
    text-align:    center;
  }

  .sidebar-heading > :first-child {
    padding: 12px;
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
    position:      relative;
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

  .tab-button {
    border-bottom:  3px solid #ffffff00;
    color:          white;
    cursor:         pointer;
    flex-grow:      1;
    padding-bottom: 12px;
    padding-top:    12px;
    user-select:    none;
  }

  .tab-button.selected {
    border-bottom-color: white;
  }

  .tab-button:not(.selected):hover {
    filter: brightness(1.5);
  }

  .thumb-action {

    position: absolute;
    top:      0;
    right:    0;

    display:         flex;
    align-items:     center;
    justify-content: center;

    width:   2rem;
    height:  2rem;
    padding: 0;

    border:        1px solid #ddd;
    border-radius: var(--radius-sm);
    box-shadow:    0 1px 3px rgba(0, 0, 0, 0.2);

    background: #c62828;
    color:      white;

    font-size:   1.5rem;
    line-height: 1;

    cursor: pointer;

    transition: background-color 0.15s, color 0.15s, transform 0.1s;

    z-index: 10;

  }

  .thumb-action:hover {
    background: #b71c1c;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.25);
  }

  .thumb-action:active {
    transform: scale(0.92);
  }

  .thumb-action:focus-visible {
    outline:        2px solid #c62828;
    outline-offset: 2px;
  }

  .unapproved.tab-button {
    background-color: darkred;
  }

  .unapproved.tab-button.selected {
    background-color: crimson;
  }

</style>
