<!-- First version made by Claude Opus 4.6 -->
<template>

  <div v-if="hasMounted && submissions.length > 0">

    <button class="btn btn-primary btn-main" @click="openUploadDialog">
      Upload your own
    </button>

    <div class="gallery-grid stagger animate-fade">
      <div
        v-for="item in submissions" :key="item.id"
        class="gallery-item"
        @click="openItem(item)"
      >
        <div class="gallery-item-thumb">
          <img v-if="item.image" :src="item.image" :alt="item.uploadName" />
          <div v-else class="no-thumb">📄</div>
        </div>
        <div class="gallery-item-info">
          <div class="gallery-item-title">
            [{{ item.uploader }}] {{ item.uploadName }}
          </div>
          <div class="gallery-item-meta">
            {{ item.comments.length }} comment{{ item.comments.length !== 1 ? 's' : '' }}
            · {{ formatDate(item.creationTime) }}
          </div>
        </div>
      </div>
    </div>

  </div>

  <div v-if="hasMounted && submissions.length === 0" class="empty-state">
    <div class="empty-state-icon">🖼️</div>
    <h3>No one has uploaded anything yet</h3>
    <button class="btn btn-primary btn-main" @click="openUploadDialog">
      Make an upload to be the first!
    </button>
  </div>

</template>

<script lang="ts">

  import { defineComponent, type PropType } from "vue";
  import { useRoute                       } from "vue-router";

  import type { Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:  "BasicGallery"
  , props: { activeSubmission: { type: Object as PropType<Submission | null>, required: true }
           , hasMounted:       { type: Boolean                              , required: true }
           , submissions:      { type: Array  as PropType<Array<Submission>>, required: true }
           }
  , emits: ["open-upload-dialog", "set-active-submission"]
  , setup(_props, { emit }) {

      useRoute();

      function formatDate(date: Date): string {

        const seconds = Math.round((Date.now() - date.getTime()) / 1000);
        const minutes = Math.round(                      seconds /   60);
        const hours   = Math.round(                      minutes /   60);
        const days    = Math.round(                        hours /   24);
        const weeks   = Math.round(                         days /    7);
        const months  = Math.round(                         days /   30);
        const years   = Math.round(                         days /  365);

        const relTime = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

        if (seconds < 60) {
          return relTime.format(-seconds, "second");
        } else if (minutes < 60) {
          return relTime.format(-minutes, "minute");
        } else if (hours < 24) {
          return relTime.format(  -hours,   "hour");
        } else if (days < 7) {
          return relTime.format(   -days,    "day");
        } else if (weeks < 5) {
          return relTime.format(  -weeks,   "week");
        } else if (months < 12) {
          return relTime.format( -months,  "month");
        } else {
          return relTime.format(  -years,   "year");
        }

      }

      function openItem(sub: Submission): void {
        emit("set-active-submission", sub);
      }

      function openUploadDialog(): void {
        emit("open-upload-dialog");
      }

      return { formatDate, openItem, openUploadDialog };

    }
  });

</script>

<style scoped>

  .btn-main {
    font-size: var(--space-4);
    padding:   var(--space-3) var(--space-4);
  }

  .gallery-grid {
    margin-top: var(--space-5);
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

</style>
