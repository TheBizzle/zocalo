<template>
  <SplitGalleryView   v-if="isSplit" />
  <StudentGalleryView v-else         />
</template>

<script lang="ts" setup>

  import { ref, watch } from "vue";
  import { useRoute   } from "vue-router";

  import SplitGalleryView   from "./views/SplitGalleryView.vue";
  import StudentGalleryView from "./views/StudentGalleryView.vue";

  const route = useRoute();

  const isSplit = ref<boolean | null>(null);

  watch(
    () => route.params["nanoid"],
    async (nanoID) => {
      const res = await fetch(`/api/galleries/${nanoID}/student/template-name`);
      if (!res.ok) {
        const message = await res.text();
        console.warn("Unknown gallery", message);
        isSplit.value = false;
      } else {
        const result = await res.text();
        isSplit.value = result.toLowerCase() !== "demo";
      }
    },
    { immediate: true }
  );

</script>
