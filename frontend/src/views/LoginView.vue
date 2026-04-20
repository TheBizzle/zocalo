<template>
  <div class="page-wrapper auth-page">
    <div class="auth-card card animate-scale">

      <!-- Step 1: Enter email -->
      <template v-if="step === 'email'">
        <div class="auth-header">
          <p class="section-eyebrow">Teacher portal</p>
          <h2>Sign in or create account</h2>
          <p class="auth-subtitle">
            If you already have an account, enter your email and we'll send you a one-time sign-in code.
          </p>
        </div>

        <div class="alert alert-danger animate-fade" v-if="errorMsg">{{ errorMsg }}</div>

        <div class="form-stack">
          <div class="form-group">
            <label class="form-label">Email address <span class="required">*</span></label>
            <input
              v-model="email"
              class="form-input"
              type="email"
              placeholder="you@school.edu"
              autocomplete="email"
              spellcheck="false"
              @keyup.enter="requestCode"
            />
          </div>
        </div>

        <button class="btn btn-primary btn-lg w-full" @click="requestCode" :disabled="loading">
          <span v-if="loading">Sending code…</span>
          <span v-else>Send sign-in code</span>
        </button>

        <p class="auth-footer-link">
          Don't have an account yet?
          <router-link to="/register">Register</router-link>
        </p>
      </template>

      <!-- Step 2: Enter OTP -->
      <template v-if="step === 'otp'">
        <div class="auth-header">
          <p class="section-eyebrow">Check your inbox</p>
          <h1>Enter your code</h1>
          <p class="auth-subtitle">
            We sent a sign-in code to <strong>{{ email }}</strong>.
            It will expire in 15 minutes.
          </p>
        </div>

        <div class="alert alert-danger animate-fade" v-if="errorMsg">{{ errorMsg }}</div>

        <div class="form-stack">
          <div class="form-group">
            <label class="form-label">One-time code <span class="required">*</span></label>
            <input
              v-model="otp"
              class="form-input otp-input"
              type="text"
              inputmode="numeric"
              placeholder="______"
              maxlength="8"
              autocomplete="one-time-code"
              @keyup.enter="verifyCode"
            />
          </div>
        </div>

        <button class="btn btn-primary btn-lg w-full" @click="verifyCode" :disabled="loading">
          <span v-if="loading">Verifying…</span>
          <span v-else>Sign in →</span>
        </button>

        <div class="resend-row">
          <button class="btn-link" @click="goBack">← Use a different email</button>
          <button class="btn-link" @click="requestCode" :disabled="resendCooldown > 0">
            {{ resendCooldown > 0 ? `Resend in ${resendCooldown}s` : "Resend code" }}
          </button>
        </div>
      </template>

    </div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, ref, onUnmounted } from "vue";
  import { useRouter                         } from "vue-router";

  import { storeToken } from "@/core/TeacherAuth.ts";

  export default defineComponent({
    name: "LoginView"
  , setup() {

      const router = useRouter();

      const step           = ref<"email" | "otp">("email");
      const email          = ref<string | null>(null);
      const errorMsg       = ref<string | null>(null);
      const isLoading      = ref(false);
      const otp            = ref<string | null>(null);
      const resendCooldown = ref(0);

      let cooldownInterval: ReturnType<typeof setInterval> | null = null;

      function startCooldown(): void {
        resendCooldown.value = 60;
        cooldownInterval = setInterval(
          () => {
            resendCooldown.value--;
            if (resendCooldown.value <= 0 && cooldownInterval !== null) {
              clearInterval(cooldownInterval);
            }
          }
        , 1000
        );
      }

      async function requestCode(): Promise<void> {

        errorMsg.value = null;

        if (email.value === null || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value)) {
          errorMsg.value = "Please enter a valid email address.";
          return;
        }

        isLoading.value = true;

        try {

          const options =
            { method: "POST"
            , headers: { "Content-Type": "application/x-www-form-urlencoded" }
            , body:    new URLSearchParams({ email: email.value })
            };

          const res = await fetch("/api/auth/teacher/request-otp", options);

          if (res.ok) {
            step.value = "otp";
            startCooldown();
          } else {
            throw new Error(await res.text());
          }

        } catch (err: unknown) {
          if (err instanceof Error) {
            errorMsg.value = err.message;
          } else {
            errorMsg.value = "Could not send code. Check your email and try again.";
          }
        } finally {
          isLoading.value = false;
        }

      }

      async function verifyCode(): Promise<void> {

        errorMsg.value = null;

        if (otp.value !== null) {

          isLoading.value = true;

          try {

            const options =
              { method: "POST"
              , headers: { "Content-Type": "application/x-www-form-urlencoded" }
              , body:    new URLSearchParams({ email: email.value!, passcode: otp.value })
              };

            const res = await fetch("/api/auth/teacher/verify-otp", options);

            if (res.ok) {
              storeToken(await res.text());
              void router.push("/galleries/teacher/overview");
            } else {
              throw new Error(await res.text());
            }

          } catch (err: unknown) {
            if (err instanceof Error) {
              errorMsg.value = err.message;
            } else {
              errorMsg.value = "Invalid or expired code. Please try again.";
            }
          } finally {
            isLoading.value = false;
          }

        } else {
          errorMsg.value = "Please enter your sign-in code.";
        }

      }

      function goBack(): void {
        step.value     = "email";
        otp.value      = null;
        errorMsg.value = null;
        if (cooldownInterval !== null) {
          clearInterval(cooldownInterval);
        }
      }

      onUnmounted(
        () => {
          if (cooldownInterval !== null) {
            clearInterval(cooldownInterval);
          }
        }
      );

      return {
        email, errorMsg, goBack, loading: isLoading, otp, requestCode, resendCooldown, step, verifyCode
      };

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

  .auth-subtitle strong {
    color: var(--clr-ink);
  }

  .form-stack {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
    margin-bottom:  var(--space-5);
  }

  .w-full {
    width:           100%;
    justify-content: center;
  }

  .otp-input {
    font-family:    "JetBrains Mono", "Courier New", monospace;
    font-size:      1.5rem;
    letter-spacing: 0.25em;
    text-align:     center;
  }

  .resend-row {
    display:         flex;
    justify-content: space-between;
    margin-top:      var(--space-4);
    flex-wrap:       wrap;
    gap:             var(--space-3);
  }

  .btn-link {
    background:  none;
    border:      none;
    cursor:      pointer;
    font-size:   0.85rem;
    color:       var(--clr-primary);
    padding:     0;
    font-family: var(--font-body);
    transition:  color var(--transition);
  }

  .btn-link:hover {
    color:           var(--clr-primary-dk);
    text-decoration: underline;
  }

  .btn-link:disabled {
    color:           var(--clr-muted);
    cursor:          default;
    text-decoration: none;
  }

  .auth-footer-link {
    text-align: center;
    font-size:  0.875rem;
    color:      var(--clr-ink-3);
    margin-top: var(--space-4);
  }

</style>
