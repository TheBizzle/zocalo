<template>
  <div id="nlw-container" class="nlw-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/NLWBlank.html?disableWorkInProgress"
            height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, ref, watch } from "vue";
  import { useRoute                               } from "vue-router";

  import type { ExportData } from "@/core/ExportData.ts";
  import { sendForAReply   } from "@/core/frameMessaging.ts";

  export default defineComponent({
    name:  "NetLogo Web"
  , props: { galleryID:     { type:  String, required: true }
           , loadedContent: { type:  String, required: true }
           , shouldExport:  { type: Boolean, required: true }
           }
  , emits: ["export-data", "hide-filler"]
  , setup(props, { emit }) {

      useRoute();

      emit("hide-filler");

      const nlwFrame = ref<HTMLIFrameElement | null>(null);

      const sendForReply = sendForAReply(
        () => nlwFrame.value?.contentWindow?.hasOwnProperty("nlwIsReady") ?? false
      , (msg: object, port: MessagePort) => { nlwFrame.value!.contentWindow?.postMessage(msg, "*", [port]); }
      );

      onMounted(
        async () => {
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
          const { nlogo, world } = JSON.parse(content) as { nlogo: string, world: string };
          await sendForReply({ nlogo, type: "nlw-load-model", path: "" });
          await sendForReply({ world, type: "nlw-import-world" });
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
          await sendForReply({ nlogo, type: "nlw-load-model", path: "" });
          await sendForReply({ world, type: "nlw-import-world" });
        }
      }

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const model = await sendForReply({ type: "nlw-export-model" }) as { "export": { result: string } };
          const state = await sendForReply({ type: "nlw-export-world" }) as { "export": string };
          const view  = await sendForReply({ type: "nlw-request-view" }) as { base64: string };
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
