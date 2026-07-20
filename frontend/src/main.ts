// First version made by Claude Opus 4.6
import { createApp                      } from "vue";
import { createRouter, createWebHistory } from "vue-router";

import App           from "./App.vue";
import GalleryRouter from "./GalleryRouter.vue";

import { amLoggedIn, amLoggedInSimple } from "./core/TeacherAuth.ts";

import LoginView             from "./views/LoginView.vue";
import MetaGalleryView       from "./views/MetaGalleryView.vue";
import RegisterView          from "./views/RegisterView.vue";
import TeacherAccConfirmView from "./views/TeacherAccConfirmView.vue";

import "./assets/styles.css";

declare module "vue-router" {
  // eslint-disable-next-line @typescript-eslint/consistent-type-definitions
  interface RouteMeta {
    isModerating?:     boolean
    disallowsTeacher?: boolean
    requiresTeacher?:  boolean
  }
}

const routes =
  [ { path: "/", redirect: "/login" }
  , { path: "/gallery/:nanoid"                     , component: GalleryRouter        , name: "student-gallery"        , meta: {  requiresStudent: true, isModerating: false } }
  , { path: "/login"                               , component: LoginView            , name: "login"                  , meta: { disallowsTeacher: true } }
  , { path: "/register"                            , component: RegisterView         , name: "register"               , meta: { disallowsTeacher: true } }
  , { path: "/galleries/teacher/confirm/:token"    , component: TeacherAccConfirmView, name: "teacher-account-confirm", meta: { disallowsTeacher: true } }
  , { path: "/galleries/teacher/moderation/:nanoid", component: GalleryRouter        , name: "moderation"             , meta: {  requiresTeacher: true, isModerating:  true } }
  , { path: "/galleries/teacher/overview"          , component: MetaGalleryView      , name: "meta-gallery"           , meta: {  requiresTeacher: true } }
  ];

const router =
  createRouter({
    history: createWebHistory()
  , routes
  , scrollBehavior() { return { top: 0 }; }
  });

router.beforeEach(
  async (to, _from, next) => {
    if (to.meta.requiresTeacher! && !(await amLoggedIn())) {
      next({ path: "/login", query: { redirect: to.fullPath } });
    } else if (to.meta.disallowsTeacher! && amLoggedInSimple()) {
      next({ path: "/galleries/teacher/overview" });
    } else {
      next();
    }
  }
);

const app = createApp(App);
app.use(router);
app.mount("#app");
