<template>
  <SplitGalleryView   v-if="activity.isSplit" :activity="activity" />
  <StudentGalleryView v-else                  :activity="activity" />
</template>

<script lang="ts" setup>

  import { ref, watch } from "vue";
  import { useRoute   } from "vue-router";

  import SplitGalleryView   from "./views/SplitGalleryView.vue";
  import StudentGalleryView from "./views/StudentGalleryView.vue";

  import type { Activity } from "@/core/Activity.ts";

  const route = useRoute();

  const nonActivity =
    { hasLoadableWork: false
    , isSplit:         false
    , name:            "fake activity"
    };

  const activity = ref<Activity>(nonActivity);

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
        switch (name) {
          case "demo":
            activity.value = { hasLoadableWork: false, isSplit: false, name };
            break;
          case "google-docs":
            activity.value = { hasLoadableWork: true, isSplit: true, name };
            break;
          default:
            throw new Error(`Unknown gallery type: ${name}`);
        }
      }
    },
    { immediate: true }
  );

</script>
