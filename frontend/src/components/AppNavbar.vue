<!-- First version made by Claude Opus 4.6 -->
<template>
  <nav class="navbar">
    <router-link to="/" class="navbar-brand">
      <span class="brand-dot"></span>
      zócalo
    </router-link>

    <ul class="navbar-links">
      <template v-if="isLoggedInAsTeacher">
        <li>
          <router-link to="/galleries/teacher/overview"
                       :class="{ active: $route.name === 'meta-gallery' }">
            My Galleries
          </router-link>
        </li>
        <li>
          <button class="btn btn-ghost btn-sm" @click="logoutAndRedirect">Sign out</button>
        </li>
      </template>
    </ul>
  </nav>
</template>

<script lang="ts">

  import { defineComponent, ref } from "vue";
  import { useRoute, useRouter  } from "vue-router";

  import { amLoggedInSimple, logout, onAuthChange } from "@/core/TeacherAuth.ts";

  export default defineComponent({
    name: "AppNavbar"
  , setup() {

      useRoute();
      const router = useRouter();

      const isLoggedInAsTeacher = ref(amLoggedInSimple());
      onAuthChange(() => { isLoggedInAsTeacher.value = amLoggedInSimple(); });

      async function logoutAndRedirect(): Promise<void> {
        await logout();
        await router.push("/login");
      }

      return { isLoggedInAsTeacher, logoutAndRedirect };

    }

  });

</script>
