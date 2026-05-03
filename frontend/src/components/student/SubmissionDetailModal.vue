<template>

  <div class="modal-overlay animate-fade" v-if="submission" @click.self="deactivate">
    <div class="modal-box item-detail-modal animate-scale">
      <button class="btn-icon modal-close" @click="deactivate">✕</button>
      <h2 style="margin-bottom: var(--space-2)">{{ submission.title }}</h2>
      <p v-if="submission.description"
         style="color: var(--clr-ink-3); font-size: 0.9rem; margin-bottom: var(--space-4)">
        {{ submission.description }}
      </p>

      <div class="item-preview">
        <img v-if="submission.thumbnail" :src="submission.thumbnail"
             :alt="submission.title" style="max-width: 100%; border-radius: var(--radius-md)" />
        <div v-else class="no-thumb-large">📄</div>
      </div>

      <div class="item-actions">
        <button class="btn btn-ghost btn-sm" @click="download(submission)">↓ Download</button>
      </div>

      <hr class="divider" />
      <CommentThread :submissionId="submission.id" :comments="submission.comments" />
    </div>
  </div>

</template>

<script lang="ts">

  import { defineComponent, type PropType } from "vue";
  import { useRoute                       } from "vue-router";

  import type { Submission } from "@/core/Submission.ts";

  import CommentThread  from "./CommentThread.vue";

  export default defineComponent({
    name:       "SubmissionDetailModal"
  , components: { CommentThread }
  , props:      { submission: { type: Object as PropType<Submission | null>, required: true } }
  , emits:      ["unset-active-submission"]
  , setup(_props, { emit }) {

      const _ = useRoute();

      function download(item: Submission): void {
        alert(`Downloading: ${item.title}`);
      }

      function deactivate(): void {
        emit("unset-active-submission");
      }

      return { download, deactivate };

    }
  });

</script>

<style scoped>

  .item-actions {
    display:       flex;
    gap:           var(--space-3);
    margin-bottom: var(--space-2);
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

  .no-thumb-large {
    width:           100%;
    height:          200px;
    display:         flex;
    align-items:     center;
    justify-content: center;
    font-size:       3rem;
  }

</style>
