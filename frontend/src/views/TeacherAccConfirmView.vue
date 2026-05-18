<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="page-wrapper auth-page">
    <div class="alert alert-danger animate-fade" v-if="errorMsg">{{ errorMsg }}</div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, ref } from "vue";
  import { useRoute, useRouter             } from "vue-router";

  import { setTitle   } from "@/composables/setTitle.ts";
  import { storeToken } from "@/core/TeacherAuth.ts";

  export default defineComponent({
    name: "TeacherAccConfirmView"
  , setup() {

      const router   = useRouter();
      const errorMsg = ref(null);

      setTitle("Confirm Your Account");

      onMounted(
        async () => {

          const route = useRoute();
          const token = route.params["token"];

          const res  = await fetch(`/api/auth/teacher/confirm/${token}`, { method: "GET" });
          const text = await res.text();

          if (res.ok) {
            storeToken(await res.text());
            void router.push("/galleries/teacher/overview");
          } else {
            throw new Error(text);
          }

        }
      );

      return { errorMsg };

    }

  });

</script>

<style scoped>
</style>
