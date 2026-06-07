<!-- First version made by Claude Opus 4.6 -->
<template>

  <div class="page-wrapper-wide">

    <div class="page-header animate-fade">
      <div>
        <h1>{{ galleryName }}</h1>
      </div>
    </div>

    <SubmissionDetailModal
      :activity="activity"
      :galleryID="galleryID"
      :isSplit="false"
      :submission="activeSubmission"
      @add-comment="addComment"
      @unset-active-submission="unsetActiveSubmission"
    />

    <UploadModal
      :isOpen="isUploadModalOpen"
      :isText="false"
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

  import { computed, defineComponent, onMounted, type PropType, ref } from "vue";
  import { useRoute                                                 } from "vue-router";

  import BasicGallery          from "@/components/student/BasicGallery.vue";
  import SubmissionDetailModal from "@/components/student/SubmissionDetailModal.vue";
  import UploadModal           from "@/components/student/UploadModal.vue";

  import type { Activity                                       } from "@/core/Activity.ts";
  import { setTitle                                            } from "@/core/setTitle.ts";
  import { authorizedFetch                                     } from "@/core/StudentAuth.ts";
  import { AllSubmissionsSchema, type Comment, type Submission } from "@/core/Submission.ts";

  export default defineComponent({
    name:       "StudentGalleryView"
  , components: { BasicGallery, SubmissionDetailModal, UploadModal }
  , props:      { activity: { type: Object as PropType<Activity>, required: true } }
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
      const galleryID         = ref<string>(route.params["nanoid"] as string);
      const galleryName       = ref("");
      const isModerated       = ref(true);
      const isUploadModalOpen = ref(false);
      const hasMounted        = ref(false);

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

      async function setActiveSubmission(sub: Submission): Promise<void> {
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

      return { activeSubmission, addComment, addNewSubmission, galleryID, galleryName, hasMounted
             , isUploadModalOpen, setActiveSubmission, unsetActiveSubmission, submissions };

    }
  });

</script>

<style scoped>
  .page-header {
    font-family:   var(--font-fancy);
    margin-bottom: var(--space-6);
  }
</style>
