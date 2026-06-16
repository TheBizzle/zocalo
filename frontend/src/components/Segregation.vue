<template>
  <div id="segregation-container" class="segregation-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/Segregation.html" height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, ref, watch } from "vue";
  import { useRoute                    } from "vue-router";

  import type { ExportData             } from "@/core/ExportData.ts";
  import { sendAMessage, sendForAReply } from "@/core/frameMessaging.ts";

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

      const sendMessage =
        sendAMessage(
          ()            =>   nlwFrame.value !== null
        , (msg: object) => { nlwFrame.value!.contentWindow?.postMessage(msg, "*"); }
        );

      const sendForReply = sendForAReply(
        ()                               =>   nlwFrame.value !== null
      , (msg: object, port: MessagePort) => { nlwFrame.value!.contentWindow?.postMessage(msg, "*", [port]); }
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
          await sendMessage({ code: content, type: "import-code" });
        }
      );

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const d           = await sendForReply({ type: "export-data" }) as { code: string, image: string };
          const imageBase64 = d.image.slice(d.image.indexOf(",") + 1);
          return { data: d.code, mimeType: "image/png", imageBase64 };
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
