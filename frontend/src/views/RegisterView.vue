<template>
  <div class="page-wrapper auth-page">
    <div class="auth-card card animate-scale">

      <div class="auth-header">
        <p class="section-eyebrow">Getting started</p>
        <div v-show="!successMsg">
          <h2>Create your teacher account</h2>
          <p class="auth-subtitle">Set up your account to create and manage student galleries</p>
        </div>
      </div>

      <div class="alert alert-success animate-fade" v-if="successMsg">
        {{ successMsg }}
      </div>
      <div class="alert alert-danger animate-fade" v-if="errorMsg">
        {{ errorMsg }}
      </div>

      <div v-if="!successMsg">
        <form @submit.prevent="submit" class="form-stack">
          <div class="form-row">
            <div class="form-group">
              <label class="form-label">First name <span class="required">*</span></label>
              <input v-model="form.firstName" class="form-input" type="text"
                     autocomplete="given-name" spellcheck="false" />
            </div>
            <div class="form-group">
              <label class="form-label">Last name <span class="required">*</span></label>
              <input v-model="form.lastName" class="form-input" type="text"
                     autocomplete="family-name" spellcheck="false" />
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">School or organization</label>
            <input v-model="form.organization" class="form-input" type="text"
                   autocomplete="organization" spellcheck="false" />
          </div>

          <div class="form-group">
            <label class="form-label">Email address <span class="required">*</span></label>
            <input v-model="form.email" class="form-input" type="email"
                   autocomplete="email" spellcheck="false" />
            <span class="form-hint">We'll send your login codes here.</span>
          </div>

          <div class="form-group">
            <label class="form-label">Confirm email <span class="required">*</span></label>
            <input v-model="form.emailConfirm" class="form-input" type="email"
                   autocomplete="email" spellcheck="false" />
          </div>

          <button type="submit" class="btn btn-primary btn-lg w-full" :disabled="loading">
            <span v-if="loading">Creating account…</span>
            <span v-else>Create account →</span>
          </button>

        </form>

        <p class="auth-footer-link">
          Already have an account?
          <router-link to="/login">Sign in</router-link>
        </p>
      </div>

    </div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, reactive, ref } from "vue";
  import { useRouter } from "vue-router";

  import { setTitle } from "@/composables/setTitle.ts";

  export default defineComponent({
    name: "RegisterView"
  , setup() {

      useRouter();

      setTitle("Create Your Zócalo Account");

      const loading    = ref(false);
      const successMsg = ref("");
      const errorMsg   = ref("");

      const form = reactive({
        firstName:    ""
      , lastName:     ""
      , organization: ""
      , email:        ""
      , emailConfirm: ""
      });

      async function submit(): Promise<void> {

        errorMsg.value   = "";
        successMsg.value = "";

        if (!form.firstName || !form.lastName || !form.email) {
          errorMsg.value = "Please fill in all required fields.";
          return;
        }

        if (form.email !== form.emailConfirm) {
          errorMsg.value = "Email addresses do not match.";
          return;
        }

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
          errorMsg.value = "Please enter a valid email address.";
          return;
        }

        loading.value = true;

        try {

          const { emailConfirm: _, ...formData } = form;

          const options =
            { method: "POST"
            , headers: { "Content-Type": "application/x-www-form-urlencoded" }
            , body:    new URLSearchParams(formData)
            };

          const res = await fetch("/api/auth/teacher/register", options);

          if (res.ok) {
            successMsg.value = `Account created! Check your inbox at ${form.email} for the confirmation link.`;
          } else {
            throw new Error(await res.text());
          }

        } catch (err: unknown) {
          if (err instanceof Error) {
            errorMsg.value = err.message;
          } else {
            errorMsg.value = "Something went wrong. Please try again.";
          }
        } finally {
          loading.value = false;
        }

      }

      return { errorMsg, form, loading, submit, successMsg };

    }
  });

</script>

<style scoped>

  .auth-page {
    max-width:       600px;
    display:         flex;
    flex-direction:  column;
    justify-content: center;
    min-height:      calc(100vh - 60px);
    padding-left:    0;
    padding-right:   0;
  }

  .auth-card {
    padding: var(--space-7);
  }

  .auth-header {
    margin-bottom: var(--space-3);
  }

  .auth-subtitle {
    color:      var(--clr-ink-3);
    font-size:  0.95rem;
    margin-top: var(--space-2);
  }

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
    margin-bottom:  var(--space-5);
  }

  .form-row {
    display:               grid;
    grid-template-columns: 1fr 1fr;
    gap:                   var(--space-4);
  }

  .w-full {
    width: 100%;
    justify-content: center;
  }

  .auth-footer-link {
    text-align: center;
    font-size:  0.875rem;
    color:      var(--clr-ink-3);
    margin-top: var(--space-4);
  }

  @media (max-width: 480px) {
    .auth-card {
      padding: var(--space-5);
    }
    .form-row {
      grid-template-columns: 1fr;
    }
  }

</style>
