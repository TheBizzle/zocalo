import { createApp                      } from "vue";
import { createRouter, createWebHistory } from "vue-router";

import App from "./App.vue";

import { amLoggedIn } from "./core/TeacherAuth.ts";

import LoginView             from "./views/LoginView.vue";
import MetaGalleryView       from "./views/MetaGalleryView.vue";
import ModerationView        from "./views/ModerationView.vue";
import RegisterView          from "./views/RegisterView.vue";
import SplitGalleryView      from "./views/SplitGalleryView.vue";
import StudentGalleryView    from "./views/StudentGalleryView.vue";
import TeacherAccConfirmView from "./views/TeacherAccConfirmView.vue";

import "./assets/styles.css";

const routes =
  [ { path: "/", redirect: "/login" }
  , { path: "/gallery/:id"                     , component: StudentGalleryView   , name: "student-gallery"        , meta: {  requiresStudent: true } }
  , { path: "/gallery/:id/split"               , component: SplitGalleryView     , name: "split-gallery"          , meta: {  requiresStudent: true } }
  , { path: "/login"                           , component: LoginView            , name: "login"                  , meta: { disallowsTeacher: true } }
  , { path: "/register"                        , component: RegisterView         , name: "register"               , meta: { disallowsTeacher: true } }
  , { path: "/moderate/:id"                    , component: ModerationView       , name: "moderation"             , meta: {  requiresTeacher: true } }
  , { path: "/galleries/teacher/confirm/:token", component: TeacherAccConfirmView, name: "teacher-account-confirm", meta: { disallowsTeacher: true } }
  , { path: "/galleries/teacher/overview"      , component: MetaGalleryView      , name: "meta-gallery"           , meta: {  requiresTeacher: true } }
  ];

const router =
  createRouter({
    history: createWebHistory()
  , routes
  , scrollBehavior() { return { top: 0 }; }
  });

router.beforeEach(
  async (to, _from, next) => {
    if ((to.meta.requiresTeacher as boolean) && !(await amLoggedIn())) {
      next({ path: "/login", query: { redirect: to.fullPath } });
    } else if ((to.meta.disallowsTeacher as boolean) && await amLoggedIn()) {
      next({ path: "/galleries/teacher/overview" });
    } else {
      next();
    }
  }
);

const app = createApp(App);
app.use(router);
app.mount("#app");
