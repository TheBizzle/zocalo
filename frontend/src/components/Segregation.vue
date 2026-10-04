<template>
  <div id="segregation-container" class="segregation-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/Segregation.html" height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, ref, watch } from "vue";
  import { useRoute                               } from "vue-router";

  import type { ExportData } from "@/core/ExportData.ts";
  import      { NLWFrame   } from "@/core/NLWFrame.ts";

  export default defineComponent({
    name:  "Segregation"
  , props: { galleryID:     { type:  String, required: true }
           , loadedContent: { type:  String, required: true }
           , shouldExport:  { type: Boolean, required: true }
           }
  , emits: ["export-data", "hide-filler"]
  , setup(props, { emit }) {

      useRoute();

      emit("hide-filler");

      const nlwFrame = ref<HTMLIFrameElement | null>(null);

      let nlw: NLWFrame | null = null;

      onMounted(
        () => {
          nlw = new NLWFrame(nlwFrame.value!);
        }
      );


      watch(
        () => props.shouldExport
      , async (shouldExport: boolean) => {
          if (shouldExport) {
            emit("export-data", await exportData());
          }
        }
      );

      watch(
        () => props.loadedContent
      , (content) => {
          const msg = { codeTabContents: content, autoRecompile: true, type: "nlw-set-model-code" };
          nlw!.enqueueUnanswerable(msg);
          setTimeout(
            () => {
              nlw!.enqueueUnanswerable({ code: "setup", type: "nlw-run-code" });
            }
          , 900
          );
        }
      );

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const { export: data } = await nlw!.enqueueExportCode();
          const { base64: view } = await nlw!.enqueueExportView();
          const imageBase64      = view.slice(view.indexOf(",") + 1);
          return { data, mimeType: "image/png", imageBase64 };
        } else {
          return undefined;
        }
      }

      return { nlwFrame };

    }

  });

</script>

<style scoped>

  .segregation-render {
    background:  white;
    color:       var(--clr-ink);
    font-family: Arial, sans-serif;
    font-size:   11pt;
    line-height: 1.15;
    padding:     1rem 1.25rem;
    overflow:    auto;
    height:      100%;
    width:       100%;
  }

  .hiding {
    display: none;
    padding: 0;
  }

</style>
