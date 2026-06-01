<!-- First version made by Claude Opus 4.6 -->
<template>

  <div ref="modalRef" class="modal-overlay animate-fade" v-if="submission" tabindex="-1"
       @click.self="deactivate" @keyup.esc="handleEsc">
    <div class="modal-box item-detail-modal animate-scale">
      <button class="btn-icon modal-close" @click="deactivate">✕</button>
      <h2 style="margin-bottom: var(--space-2)">
        {{ submission.uploader }}
      </h2>

      <div class="scroll-pane">

        <div class="item-preview">
          <img v-if="submission?.image" :src="submission?.image"
               :alt="submission?.uploader" style="max-width: 100%; border-radius: var(--radius-md)" />
          <div v-else class="no-thumb-large">📄</div>
        </div>

        <p v-if="description"
           style="color: var(--clr-ink-3); font-size: 1rem; margin-bottom: var(--space-4)">
          <div class="timestamp">{{ formatDate(submission.creationTime) }}</div>
          {{ description }}
        </p>

        <div class="item-actions">
          <a class="btn btn-primary btn-lg dl-button"
             :href="`/api/galleries/${galleryID}/student/${submission.id}`"
             :download="submission.uploader">↓ Download</a>
          <button class="btn btn-primary btn-lg" @click="loadInSplit">
            <span class="dl-icon">👀</span> Load
          </button>
        </div>

        <hr class="divider" />
        <CommentThread :comments="submission.comments" :galleryID="galleryID"
                       :submissionName="submission.uploader" />

      </div>

    </div>
  </div>

</template>

<script lang="ts">

  import { computed, defineComponent, nextTick, type PropType, ref, watch } from "vue";
  import { useRoute                                                       } from "vue-router";

  import { formatDate      } from "@/core/formatDate.ts";
  import type { Submission } from "@/core/Submission.ts";

  import CommentThread  from "./CommentThread.vue";

  export default defineComponent({
    name:       "SubmissionDetailModal"
  , components: { CommentThread }
  , props:      { galleryID:  { type: String                               , required: true }
                , isSplit:    { type: Boolean                              , required: true }
                , submission: { type: Object as PropType<Submission | null>, required: true }
                }
  , emits:      ["load-in-split", "unset-active-submission"]
  , setup(props, { emit }) {

      useRoute();

      const modalRef = ref<HTMLDivElement | null>(null);

      watch(
        () => props.submission
      , async (sub) => {
          if (sub !== null) {
            await nextTick();
            modalRef.value?.focus();
          }
        }
      );

      const description =
        computed(
          (): string | null => {
            if (props.submission?.metadata !== undefined && props.submission.metadata !== null) {
              try {
                const parsed = JSON.parse(props.submission.metadata) as { description?: string };
                return parsed.description ?? null;
              } catch {
                return null;
              }
            } else {
              return null;
            }
          }
        );

      function deactivate(): void {
        emit("unset-active-submission");
      }

      function handleEsc(e: KeyboardEvent): void {
        const target  = e.target as HTMLElement;
        const isInput = ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName);
        if (!isInput) {
          deactivate();
        } else {
          modalRef.value?.focus();
        }
      }

      function loadInSplit(): void {
        emit("load-in-split", props.submission!);
        emit("unset-active-submission");
      }

      return { description, deactivate, formatDate, handleEsc, loadInSplit, modalRef };

    }
  });

</script>

<style scoped>

  .dl-button {
    color:     white;
    font-size: 1.1rem;
    padding:   10px 20px;
  }

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

  .scroll-pane {
    max-height:    60vh;
    overflow-y:    auto;
    padding-right: var(--space-6);
  }

  .timestamp {
    color:       var(--clr-accent);
    font-weight: bold;
  }

</style>
