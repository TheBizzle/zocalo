<template>
  <div class="gallery-grid stagger animate-fade">
    <div
      v-for="item in submissions" :key="item.id"
      class="gallery-item"
      @click="openItem(item)"
    >
      <div class="gallery-item-thumb">
        <img v-if="item.thumbnail" :src="item.thumbnail" :alt="item.title" />
        <div v-else class="no-thumb">📄</div>
      </div>
      <div class="gallery-item-info">
        <div class="gallery-item-title">{{ item.title }}</div>
        <div class="gallery-item-meta">
          {{ item.commentCount }} comment{{ item.commentCount !== 1 ? 's' : '' }}
          · {{ formatDate(item.submittedAt) }}
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, type PropType } from "vue";
  import { useRoute                       } from "vue-router";

  import type { Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:  "BasicGallery"
  , props: { activeSubmission: { type: Object as PropType<Submission | null>, required: true }
           , submissions:      { type: Array as PropType<Array<Submission>> , required: true }
           }
  , emits: ["set-active-submission"]
  , setup(_props, { emit }) {

      useRoute();

      function formatDate(d: Date): string {
        return d.toLocaleDateString("en-US", { day: "numeric", month: "short" });
      }

      function openItem(sub: Submission): void {
        emit("set-active-submission", sub);
      }

      return { formatDate, openItem };

    }
  });

</script>

<style scoped>

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
