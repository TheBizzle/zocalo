<template>
  <nav class="navbar" v-if="showNav">
    <router-link to="/" class="navbar-brand">
      <span class="brand-dot"></span>
      zócalo
    </router-link>

    <ul class="navbar-links">
      <template v-if="isTeacherRoute">
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

  import { defineComponent, computed } from "vue";
  import { useRoute, useRouter       } from "vue-router";

  import { logout } from "@/core/TeacherAuth.ts";

  export default defineComponent({
    name: "AppNavbar"
  , setup() {

      const route  = useRoute();
      const router = useRouter();

      const teacherRoutes = ["meta-gallery",       "moderation"];
      const hideNavRoutes = ["student-gallery", "split-gallery"];

      const isTeacherRoute = computed(() =>  teacherRoutes.includes(route.name as string));
      const showNav        = computed(() => !hideNavRoutes.includes(route.name as string));

      async function logoutAndRedirect(): Promise<void> {
        await logout();
        await router.push("/login");
      }

      return { isTeacherRoute, logoutAndRedirect, showNav };

    }

  });

</script>
