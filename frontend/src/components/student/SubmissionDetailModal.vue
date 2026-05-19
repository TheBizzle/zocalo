<!-- First version made by Claude Opus 4.6 -->
<template>

  <div ref="modalRef" class="modal-overlay animate-fade" v-if="submission" tabindex="-1"
       @click.self="deactivate" @keyup.esc="handleEsc">
    <div class="modal-box item-detail-modal animate-scale">
      <button class="btn-icon modal-close" @click="deactivate">✕</button>
      <h2 style="margin-bottom: var(--space-2)">{{ submission.uploadName }}</h2>
      <hr style="margin-left: 0px; margin-right: 46px">

      <div class="scroll-pane">

        <div class="item-preview">
          <img v-if="submission?.image" :src="submission?.image"
               :alt="submission?.uploadName" style="max-width: 100%; border-radius: var(--radius-md)" />
          <div v-else class="no-thumb-large">📄</div>
        </div>

        <p v-if="description"
           style="color: var(--clr-ink-3); font-size: 0.9rem; margin-bottom: var(--space-4)">
          {{ description }}
        </p>

        <div class="item-actions">
          <button class="btn btn-ghost btn-sm" @click="download(submission)">↓ Download</button>
        </div>

        <hr class="divider" />
        <CommentThread :comments="submission.comments" :galleryID="galleryID"
                       :submissionName="submission.uploadName" />

      </div>

    </div>
  </div>

</template>

<script lang="ts">

  import { computed, defineComponent, nextTick, type PropType, ref, watch } from "vue";
  import { useRoute                                                       } from "vue-router";

  import type { Submission } from "@/core/Submission.ts";

  import CommentThread  from "./CommentThread.vue";

  export default defineComponent({
    name:       "SubmissionDetailModal"
  , components: { CommentThread }
  , props:      { galleryID:  { type: String                               , required: true }
                , submission: { type: Object as PropType<Submission | null>, required: true }
                }
  , emits:      ["unset-active-submission"]
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

      function download(item: Submission): void {
        alert(`Downloading: ${item.uploadName}`);
      }

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

      return { description, download, deactivate, handleEsc, modalRef };

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

  .scroll-pane {
    max-height:    60vh;
    overflow-y:    auto;
    padding-right: var(--space-6);
  }

</style>
