<template>
  <div id="segregation-container" class="segregation-render">
    <iframe ref="nlwFrame" id="nlw-frame" src="/html/Segregation.html" height="100%" width="100%" ></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, ref, watch } from "vue";
  import { useRoute                    } from "vue-router";

  import type { ExportData } from "@/core/ExportData.ts";

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

      watch(
        () => props.shouldExport
      , async (shouldExport: boolean) => {
          if (shouldExport) {
            emit("export-data", await exportData());
          }
        }
      );

      let waitingData: string | null = null;
      const peskyLoop = // Load the waiting data, once the frame is loaded
        setInterval(
          () => {
            if (nlwFrame.value !== null) {
              clearInterval(peskyLoop);
              if (waitingData !== null) {
                const msg = { code: waitingData, type: "import-code" };
                nlwFrame.value.contentWindow?.postMessage(msg, "*");
              }
            }
          }
        , 50
        );

      watch(
        () => props.loadedContent
      , async (content) => {
          if (nlwFrame.value !== null) {
            const msg = { code: content, type: "import-code" };
            nlwFrame.value.contentWindow?.postMessage(msg, "*");
          } else {
            waitingData = content;
          }
        }
      );

      async function walkieTalkie(message: object): Promise<object> {
        return new Promise(
          (resolve, reject) => {

            const channel = new MessageChannel();

            channel.port1.onmessage = (response: MessageEvent<object>): void => {
              resolve(response.data);
              channel.port1.close();
            };

            nlwFrame.value?.contentWindow?.postMessage(message, "*", [channel.port2]);

            setTimeout(
              () => {
                reject(new Error("Walkie talkie timed out"));
                channel.port1.close();
              }
            , 5000
            );

          }
        );
      }

      async function exportData(): Promise<ExportData | undefined> {
        if (nlwFrame.value !== null) {
          const d           = await walkieTalkie({ type: "export-data" }) as { code: string, image: string };
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
