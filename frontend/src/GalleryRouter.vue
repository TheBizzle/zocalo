<template>
  <template v-if="activity">
    <SplitGalleryView   v-if="activity.isSplit" :activity="activity" :isModerating="isModerating" />
    <StudentGalleryView v-else                  :activity="activity" :isModerating="isModerating" />
  </template>
</template>

<script lang="ts" setup>

  import { computed, ref, watch } from "vue";
  import { useRoute             } from "vue-router";

  import SplitGalleryView   from "./views/SplitGalleryView.vue";
  import StudentGalleryView from "./views/StudentGalleryView.vue";

  import { activities, type Activity } from "@/core/Activity.ts";

  const route = useRoute();

  const activity = ref<Activity | null>(null);

  watch(
    () => route.params["nanoid"],
    async (nanoID) => {
      const res = await fetch(`/api/galleries/${nanoID}/student/template-name`);
      if (!res.ok) {
        const message = await res.text();
        console.warn("Unknown gallery", message);
      } else {
        const result = await res.text();
        const name   = result.toLowerCase();
        const activ  = activities[name];
        if (activ === undefined) {
          throw new Error(`Unknown gallery type: ${name}`);
        } else {
          activity.value = activ;
        }
      }
    },
    { immediate: true }
  );

  const isModerating = computed(() => route.meta.isModerating ?? false);

</script>
