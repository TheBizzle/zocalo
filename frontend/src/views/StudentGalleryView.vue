<template>

  <nav class="student-nav">
    <router-link to="/" class="navbar-brand">
      <span class="brand-dot"></span>
      zócalo
    </router-link>
  </nav>

  <div class="page-wrapper-wide">

    <div class="page-header animate-fade">
      <div>
        <h1>{{ galleryName }}</h1>
      </div>
    </div>

    <SubmissionDetailModal
      :submission="activeSubmission"
      @unset-active-submission="unsetActiveSubmission"
    />

    <UploadModal
      :isOpen="isUploadModalOpen"
      @add-new-submission="addNewSubmission"
      @close-dialog="isUploadModalOpen = false"
    />

    <BasicGallery
      :activeSubmission="activeSubmission"
      :submissions="submissions"
      @open-upload-dialog="isUploadModalOpen = true"
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

      useRoute();

      const activeSubmission  = ref<Submission | null>(null);
      const galleryName       = ref("Spring Art Showcase");
      const isUploadModalOpen = ref(false);

      // TODO: Demo submissions
      const submissions =
        ref<Array<Submission>>(
          [ { id:           1
            , data:         null
            , uploadName:   "Still Life — Fruit Bowl"
            , image:        "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
            , isOwner:      false
            , canModerate:  false
            , metadata:     "{ description: 'Oil pastel on paper.' }"
            , comments: [
                { id: 1, author: "Jamie", comment:      "I love the colours you chose!"
                , parentID: null, creationTime: new Date("2025-04-02") }
              , { id: 2, author:   "Sam", comment: "Really nice shading on the banana."
                , parentID:    1, creationTime: new Date("2025-04-03") }
            , ]
            , creationTime: new Date("2025-04-01")
            }
          , { id:           2
            , data:         null
            , uploadName:   "Portrait Study"
            , image:        "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
            , isOwner:      true
            , canModerate:  false
            , metadata:     null
            , creationTime: new Date("2025-03-28")
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

      return { activeSubmission, addNewSubmission, galleryName, isUploadModalOpen, setActiveSubmission
             , unsetActiveSubmission, submissions };

    }
  });

</script>

<style scoped>

  .page-header {
    font-family:   var(--font-fancy);
    margin-bottom: var(--space-6);
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
