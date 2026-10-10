<template>
  <div id="nlw-container" class="nlw-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/NLWBlank.html?disableWorkInProgress"
            height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, ref, type PropType, watch } from "vue";
  import { useRoute                                              } from "vue-router";

  import type { ExportData } from "@/core/ExportData.ts";
  import      { NLWFrame   } from "@/core/NLWFrame.ts";

  export default defineComponent({
    name:  "NetLogo Web"
  , props: { galleryID:     { type:  String, required: true }
           , shouldExport:  { type: Boolean, required: true }
           // eslint-disable-next-line @typescript-eslint/no-wrapper-object-types
           , loadedContent: { type: String as PropType<String>, required: true }
           }
  , emits: ["export-data", "hide-filler"]
  , setup(props, { emit }) {

      useRoute();

      emit("hide-filler");

      const nlwFrame = ref<HTMLIFrameElement | null>(null);

      let nlw: NLWFrame | null = null;

      onMounted(
        async () => {
          nlw = new NLWFrame(nlwFrame.value!);
          await fetchStarter();
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
      , async (content) => {
          const json = content.valueOf();
          if (json !== "") {
            const { nlogo, world } = JSON.parse(json) as { nlogo: string, world: string };
            nlw!.enqueueUnanswerable({ nlogo, path: "", type: "nlw-load-model" });
            setTimeout(
              () => { void nlw!.enqueueImportWorld(world); }
            , 900
            );
          }
        }
      );

      async function fetchStarter(): Promise<void> {
        const res = await fetch(`/api/galleries/${props.galleryID}/student/starter-config`);
        if (!res.ok) {
          const message = await res.text();
          alert(`Could not fetch starter: ${message}`);
        } else {
          type Expected = { ".nlogox": string, ".csv": string };
          const { ".nlogox": nlogo, ".csv": world } = JSON.parse(await res.text()) as Expected;
          nlw!.enqueueUnanswerable({ nlogo, path: "", type: "nlw-load-model" });
          setTimeout(
            () => { void nlw!.enqueueImportWorld(world); }
          , 900
          );
        }
      }

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const model = await nlw!.enqueueExportModel();
          const state = await nlw!.enqueueExportWorld();
          const view  = await nlw!.enqueueExportView();
          const data  = JSON.stringify({ nlogo: model.export.result, world: state.export });
          const imageBase64 = view.base64.slice(view.base64.indexOf(",") + 1);
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

  .nlw-render {
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
