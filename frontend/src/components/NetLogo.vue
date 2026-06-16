<template>
  <div id="nlw-container" class="nlw-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/NLWBlank.html?disableWorkInProgress"
            height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, ref, watch } from "vue";
  import { useRoute                               } from "vue-router";

  import type { ExportData             } from "@/core/ExportData.ts";
  import { sendAMessage, sendForAReply } from "@/core/frameMessaging.ts";

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

      const sendMessage =
        sendAMessage(
          () => nlwFrame.value?.contentWindow?.hasOwnProperty("nlwIsReady") ?? false
        , (msg: object) => { nlwFrame.value!.contentWindow?.postMessage(msg, "*"); }
        );

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
          await sendMessage({ nlogo: content, path: "", type: "nlw-load-model" });
        }
      );

      async function fetchStarter(): Promise<void> {
        const res = await fetch(`/api/galleries/${props.galleryID}/student/starter-config`);
        if (!res.ok) {
          const message = await res.text();
          alert(`Could not fetch starter: ${message}`);
        } else {
          await sendMessage({ nlogo: await res.text(), path: "", type: "nlw-load-model" });
        }
      }

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const model = await sendForReply({ type: "nlw-export-model" }) as { "export": { result: string } };
          const view  = await sendForReply({ type: "nlw-request-view" }) as { base64: string };
          const imageBase64 = view.base64.slice(view.base64.indexOf(",") + 1);
          return { data: model.export.result, mimeType: "image/png", imageBase64 };
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
