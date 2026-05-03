<template>

  <nav class="student-nav">
    <router-link to="/" class="navbar-brand">
      <span class="brand-dot"></span>
      zócalo
    </router-link>
    <div class="gallery-name">{{ galleryName }}</div>
  </nav>

  <div class="page-wrapper-wide">
    <SubmissionDetailModal
      :submission="activeSubmission"
      @unset-active-submission="unsetActiveSubmission"
    />
    <UploadModal />
    <BasicGallery
      :activeSubmission="activeSubmission"
      :submissions="submissions"
      @set-active-submission="setActiveSubmission"
    />
  </div>

</template>

<script lang="ts">

  import { computed, defineComponent, ref } from "vue";
  import { useRoute                       } from "vue-router";

  import BasicGallery          from "@/components/student/BasicGallery.vue";
  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";

  import { setTitle } from "@/composables/setTitle.ts";

  import type { Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:       "StudentGalleryView"
  , components: { BasicGallery, SubmissionDetailModal, UploadModal }
  , setup() {

      const _ = useRoute();

      const activeSubmission = ref<Submission | null>(null);
      const galleryName      = ref("Spring Art Showcase");

      // TODO: Demo submissions
      const submissions =
        ref<Array<Submission>>(
          [ { id:           "1"
            , title:        "Still Life — Fruit Bowl"
            , description:  "Oil pastel on paper."
            , thumbnail:    "https://picsum.photos/seed/art3/400/300"
            , submittedAt:  new Date("2025-04-01")
            , commentCount: 4
            , comments: [
                { id: "c1", author: "Jamie", text:      "I love the colours you chose!", createdAt: new Date("2025-04-02") }
              , { id: "c2", author:   "Sam", text: "Really nice shading on the banana.", createdAt: new Date("2025-04-03") }
            , ]
            }
          , { id:           "2"
            , title:        "Portrait Study"
            , description:  ""
            , thumbnail:    "https://picsum.photos/seed/art4/400/300"
            , submittedAt:  new Date("2025-03-28")
            , commentCount: 2
            , comments:     []
            }
          ]
        );

      function addNewSubmission(sub: Submission): void {
        submissions.value.unshift(sub);
      }

      function setActiveSubmission(sub: Submission): void {
        activeSubmission.value = sub;
      }

      function unsetActiveSubmission(): void {
        activeSubmission.value = null;
      }

      const title = computed(() => `${galleryName.value} Gallery`);
      setTitle(title);

      return { activeSubmission, addNewSubmission, galleryName, setActiveSubmission
             , unsetActiveSubmission, submissions };

    }
  });

</script>

<style scoped>

  @import url('https://fonts.googleapis.com/css2?family=Lora:wght@400&display=swap');

  .gallery-name {
    font-family:    "Lora", Georgia, serif;
    font-size:      clamp(1.25rem, 2.5vw, 1.75rem);
    font-weight:    400;
    letter-spacing: 0.02em;
    color:          var(--color-ink);
  }

  .student-nav {
    position:                sticky;
    top:                     0;
    z-index:                 100;
    display:                 grid;
    grid-template-columns:   1fr auto 1fr;
    align-items:             center;
    background:              rgba(253,246,238,0.92);
    -webkit-backdrop-filter: blur(12px);
    backdrop-filter:         blur(12px);
    border-bottom:           1px solid var(--clr-border-2);
    padding:                 0 var(--space-6);
    height:                  60px;
  }

</style>
