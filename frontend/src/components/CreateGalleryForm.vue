<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="create-form card animate-fade">
    <button class="btn-back" @click.stop="cancelForm">
      <svg width="24" height="19" viewBox="0 0 20 16" fill="none" aria-hidden="true"
           xmlns="http://www.w3.org/2000/svg">
        <path d="M17 8H3M3 8l4.5-4.5M3 8l4.5 4.5" stroke="currentColor" stroke-width="1.5"
              stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
    <h2 style="margin-bottom: var(--space-6)">Create a new gallery</h2>

    <div class="alert alert-danger" v-if="errorMsg">{{ errorMsg }}</div>
    <div class="alert alert-success" v-if="successMsg">{{ successMsg }}</div>

    <div class="form-flex">

      <!-- Name -->
      <div class="form-group span-2">
        <label class="form-label">Gallery name <span class="required">*</span></label>
        <input v-model="form.name" class="form-input" type="text"
               placeholder="e.g. Math 102 > Spring 2026 > Section 2" />
      </div>

      <!-- Template -->
      <div class="form-group span-2">
        <label class="form-label">Template <span class="required">*</span></label>
        <select v-model="form.template" class="form-select">
          <option value="">— Select a template —</option>
          <option v-for="t in templates" :key="t.id" :value="t.id" :disabled="t.isDisabled">
            {{ t.name }}
          </option>
        </select>
        <span class="form-hint" v-if="selectedTemplate">{{ selectedTemplate.description }}</span>
      </div>

      <!-- Moderation toggle -->
      <div class="form-group span-2">
        <label class="form-label">
          Enable moderation?
          <InfoIndicator aria-label="Moderation info">
              <strong>Off</strong>: Student uploads instantly appear in the public gallery.<br><br>
              <strong>On</strong>: Each upload must be approved by you on the moderation page before
                                   becoming visible to everyone else.
          </InfoIndicator>
        </label>
        <Switcher v-model="form.isModerated" />
      </div>

      <!-- Description -->
      <div class="form-group span-2">
        <label class="form-label">
          Description <span class="text-muted" style="font-weight: 400">(optional)</span>
        </label>
        <textarea v-model="form.description" class="form-textarea" rows="3"></textarea>
      </div>

      <!-- Starter data -->
      <div v-if="starterKeys.length > 0" class="form-group span-2">

        <label class="form-label">
          Starter data
          <span class="text-muted" style="font-weight: 400">(optional)</span>
        </label>

        <div class="starter-tabs-wrapper">
          <div class="tab-headers">
            <button v-for="(tab, index) in starterKeys" :key="index"
                    :class="['tab-button', { active: starterIndex === index }]" @click="starterIndex = index">
              {{ tab }}
            </button>
          </div>
          <div v-for="(key, index) in starterKeys" class="form-group span-2" v-show="starterIndex === index">
            <StarterUploadForm :key="key" :ref="(elem) => setStarterRef(elem, index)"/>
          </div>
        </div>

      </div>

    </div>

    <div class="form-actions">
      <button class="btn btn-ghost" @click="cancelForm">Cancel</button>
      <button class="btn btn-primary btn-lg" @click="submit" :disabled="isLoading">
        <span v-if="isLoading">Creating...</span>
        <span v-else>Create gallery →</span>
      </button>
    </div>

  </div>
</template>

<script lang="ts">

  import { computed, defineComponent, reactive, ref } from "vue";

  import { activities       } from "@/core/Activity.ts";
  import { uploadNewGallery } from "@/core/uploadNewGallery.ts";

  import InfoIndicator     from "./InfoIndicator.vue";
  import StarterUploadForm from "./StarterUploadForm.vue";
  import Switcher          from "./Switcher.vue";

  type Template =
    { id:          string
    , name:        string
    , isDisabled:  boolean
    , description: string
    }

  export default defineComponent({
    name:       "CreateGalleryForm"
  , components: { InfoIndicator, StarterUploadForm, Switcher }
  , emits:      ["canceled", "created"]
  , setup(_, { emit }) {

      const errorMsg     = ref<string | null>(null);
      const isLoading    = ref(false);
      const starterIndex = ref(0);
      const starterRefs  = ref<Array<InstanceType<typeof StarterUploadForm>>>([]);
      const successMsg   = ref<string | null>(null);

      const templates: Array<Template> =
        [ { id:      "geogebra", name: "GeoGebra",             isDisabled: false, description: "Students upload GeoGebra constructions" }
        , { id:   "google-docs", name: "Google Docs",          isDisabled: false, description: "Students upload content from a seed Google Doc" }
        , { id:       "netlogo", name: "NetLogo",              isDisabled: false, description: "Students upload NetLogo models" }
        , { id: "netlogo-world", name: "NetLogo + world",      isDisabled:  true, description: "Students upload NetLogo models and world states" }
        , { id:   "segregation", name: "NetLogo: Segregation", isDisabled: false, description: "Students upload variations of NetLogo's Segregation model" }
        , { id:      "netsblox", name: "NetsBlox",             isDisabled:  true, description: "Students upload NetsBlox programs" }
        , { id:          "demo", name: "Demo",                 isDisabled: false, description: "Simple demo gallery with a grid of images and files" }
        ];

      const form = reactive({
        name:        ""
      , template:    ""
      , isModerated: false
      , description: ""
      });

      const selectedTemplate = computed(() => templates.find(t => t.id === form.template) ?? null);

      const starterKeys = computed<Array<string>>(
        () => {
          const name = (selectedTemplate.value?.id ?? "Demo").toLowerCase();
          return activities[name]?.starterKeys ?? [];
        }
      );

      function resetForm(): void {

        form.name        = "";
        form.template    = "";
        form.isModerated = false;
        form.description = "";
        errorMsg.value   = null;
        successMsg.value = null;

        starterRefs.value.forEach((comp) => { comp.reset(); }); // eslint-disable-line

      }

      function cancelForm(): void {
        resetForm();
        emit("canceled");
      }

      function setStarterRef(component: unknown, index: number): void {
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        starterRefs.value[index] = component as InstanceType<typeof StarterUploadForm>;
      }

      async function submit(): Promise<void> {

        errorMsg.value   = null;
        successMsg.value = null;

        if (form.name.trim() === "") {
          errorMsg.value = "Please enter a gallery name.";
          return;
        }

        if (form.template === "") {
          errorMsg.value = "Please select a template.";
          return;
        }

        isLoading.value = true;

        try {

          let starterData = "";
          if (starterRefs.value.length < 2) {
            // eslint-disable-next-line
            starterRefs.value.forEach((comp) => { starterData = comp.getData() ?? ""; });
          } else {
            const starters: Record<string, string> = {};
            starterKeys.value.forEach(
              (key: string, i: number) => {
                starters[key] = starterRefs.value[i]?.getData() ?? ""; // eslint-disable-line
              }
            );
            starterData = JSON.stringify(starters);
          }

          const newGalleryR =
            await uploadNewGallery(form.name, form.template, form.isModerated, form.description, starterData);

          newGalleryR.fold(
            (error  ) => { errorMsg.value = error.message; }
          , (gallery) => {
              successMsg.value = `Gallery "${gallery.name}" created!`;
              emit("created", gallery);
            }
          );

          resetForm();

        } catch (err: unknown) {
          if (err instanceof Error) {
            errorMsg.value = err.message;
          } else {
            errorMsg.value = "Could not create gallery. Please try again.";
          }
        } finally {
          isLoading.value = false;
        }

      }

      return {
        cancelForm, errorMsg, form, isLoading, resetForm, selectedTemplate, setStarterRef, starterIndex
      , starterKeys, starterRefs, submit, successMsg, templates
      };

    }
  });

</script>

<style scoped>

  .create-form {
    max-width: 760px;
    padding:   var(--space-5) var(--space-7) var(--space-7);
  }

  .form-flex {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-5);
    margin-bottom:  var(--space-6);
  }

  .span-2 {
    grid-column: span 2;
  }

  .form-actions {
    display:         flex;
    justify-content: flex-end;
    gap:             var(--space-3);
  }

  .btn-back {
    display:     inline-flex;
    align-items: center;
    gap:         6px;

    background:    transparent;
    border:        none;
    border-radius: 6px;
    cursor:        pointer;
    margin:        0 0 18px;
    padding:       4px 2px;
    font-size:     22px;
    transition:    background 0.15s, transform 0.1s;
  }

  .btn-back:hover {
    background-color: rgb(225, 225, 225);
  }

  .btn-link {
    background:  none;
    border:      none;
    cursor:      pointer;
    color:       var(--clr-primary);
    font-family: var(--font-body);
    font-size:   0.85rem;
  }

  .btn-link:hover {
    text-decoration: underline;
  }

  .noticeable {
    color: black;
  }

  .starter-tabs-wrapper {
    border:        1.5px solid var(--clr-border);
    border-radius: var(--radius-md);
  }

  .tab-headers {
    display:       flex;
    gap:           0;
    background:    var(--clr-surface-2);
    border-radius: var(--radius-md) var(--radius-md) 0 0;
    border-bottom: 1.5px solid var(--clr-border);
    padding:       var(--space-2) var(--space-2) 0;
  }

  .tab-button {
    background-color: transparent;
    border:           1.5px solid var(--clr-border);
    border-bottom:    none;
    border-radius:    var(--radius-sm) var(--radius-sm) 0 0;
    color:            var(--clr-ink-3);
    cursor:           pointer;
    font-family:      var(--font-body);
    font-size:        0.8rem;
    font-weight:      500;
    margin-bottom:    -1.5px;
    padding:          6px 16px;
    transition:       all var(--transition);
  }

  .tab-button:hover {
    color:            var(--clr-ink);
    background-color: var(--clr-surface);
  }

  .tab-button.active {
    background-color:    var(--clr-surface);
    border-color:        var(--clr-border);
    border-bottom-color: var(--clr-surface);
    color:               var(--clr-primary-dk);
  }

  @media (max-width: 560px) {
    .form-grid {
      grid-template-columns: 1fr;
    }
    .span-2 {
      grid-column: span 1;
    }
  }

</style>
