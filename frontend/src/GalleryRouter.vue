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

  const nonActivity: Activity =
    { hasExternalStarter: false
    , hasLoadableWork:    false
    , isSplit:            false
    , name:               "fake activity"
    , sharingStyle:       "file-picker"
    };

  const activity = ref<Activity>(nonActivity);

  const activities: Record<string, Activity>  =
    { "demo":        { hasExternalStarter: false, hasLoadableWork: false, isSplit: false, name:        "demo", sharingStyle: "file-picker" }
    , "geogebra":    { hasExternalStarter: false, hasLoadableWork:  true, isSplit:  true, name:    "geogebra", sharingStyle:      "export" }
    , "google-docs": { hasExternalStarter:  true, hasLoadableWork:  true, isSplit:  true, name: "google-docs", sharingStyle:   "clipboard" }
    };

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

</script>
