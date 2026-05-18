<!-- First version made by Claude Opus 4.6 -->
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
      :hasMounted="hasMounted"
      :submissions="submissions"
      @open-upload-dialog="isUploadModalOpen = true"
      @set-active-submission="setActiveSubmission"
    />

  </div>

</template>

<script lang="ts">

  import { computed, defineComponent, onMounted, ref } from "vue";
  import { useRoute                                  } from "vue-router";

  import BasicGallery          from "@/components/student/BasicGallery.vue";
  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";

  import { setTitle } from "@/composables/setTitle.ts";

  import { authorizedFetch                       } from "@/core/StudentAuth.ts";
  import { AllSubmissionsSchema, type Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:       "StudentGalleryView"
  , components: { BasicGallery, SubmissionDetailModal, UploadModal }
  , setup() {

      const route = useRoute();

      const submissions = ref<Array<Submission>>([]);
      onMounted(
        async () => {
          await updateSubmissions();
          hasMounted.value = true;
        }
      );

      const activeSubmission  = ref<Submission | null>(null);
      const galleryName       = ref("");
      const isModerated       = ref(true);
      const isUploadModalOpen = ref(false);
      const hasMounted        = ref(false);

      function addNewSubmission(sub: Submission): void {
        if (!isModerated.value) {
          submissions.value.unshift(sub);
        }
      }

      function setActiveSubmission(sub: Submission): void {
        activeSubmission.value = sub;
      }

      function unsetActiveSubmission(): void {
        activeSubmission.value = null;
      }

      async function updateSubmissions(): Promise<void> {
        const galleryID = route.params["nanoid"];
        const result    = await authorizedFetch(`/api/galleries/student/submissions/${galleryID}`);
        if (result.ok) {
          const subs        = AllSubmissionsSchema.parse(await result.json());
          isModerated.value = subs.isModerated;
          submissions.value = subs.submissions;
          galleryName.value = subs.galleryName;
        } else {
          alert(await result.text());
        }
      }

      const title = computed(() => `${galleryName.value} Gallery`);
      setTitle(title);

      return { activeSubmission, addNewSubmission, galleryName, hasMounted, isUploadModalOpen
             , setActiveSubmission, unsetActiveSubmission, submissions };

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
