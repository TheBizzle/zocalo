<template>
  <div id="sweeps-container" class="sweeps-render">
    <iframe ref="iframe" id="sweeper-frame" src="/html/sweeping-area.html"
            height="100%" width="100%"></iframe>
  </div>
</template>

<script lang="ts">

  import { defineComponent, onMounted, onUnmounted, ref, watch } from "vue";
  import { useRoute                                            } from "vue-router";

  import type { ExportData  } from "@/core/ExportData.ts";
  import { makeCommsChannel } from "@/core/frameMessaging.ts";

  export default defineComponent({
    name:  "Sweeping Area"
  , props: { galleryID:     { type:  String, required: true }
           , loadedContent: { type:  String, required: true }
           , shouldExport:  { type: Boolean, required: true }
           }
  , emits: ["export-data", "hide-filler"]
  , setup(props, { emit }) {

      useRoute();

      emit("hide-filler");

      const iframe = ref<HTMLIFrameElement | null>(null);

      const [theirPort, sendForReply] = makeCommsChannel();

      onMounted(
        async () => {
          window.addEventListener("message", onMessage);
          await fetchStarter();
        }
      );

      onUnmounted(() => {
        window.removeEventListener("message", onMessage);
      });

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
          void sendForReply({ state: JSON.parse(content) as object, type: "loadState" }, false);
        }
      );

      function onMessage(event: MessageEvent): void {
        if (event.source === iframe.value?.contentWindow) {
          if ((event.data as { type: string }).type === "ready") {
            iframe.value.contentWindow?.postMessage({ type: "connect" }, "*", [theirPort]);
          }
        }
      }

      async function fetchStarter(): Promise<void> {
        const res = await fetch(`/api/galleries/${props.galleryID}/student/starter-config`);
        if (res.ok) {
          void sendForReply({ state: JSON.parse(await res.text()) as object, type: "loadState" }, false);
        }
      }

      async function exportData(): Promise<ExportData | undefined> {
        if (iframe.value !== null) {
          type Response = { type: "state", state: object, thumbnail: string };
          const response    = await sendForReply({ type: "requestState" }, true) as Response;
          const data        = JSON.stringify(response.state);
          const imageBase64 = response.thumbnail.slice(response.thumbnail.indexOf(",") + 1);
          return { data, mimeType: "image/jpeg", imageBase64 };
        } else {
          return undefined;
        }
      }

      return { iframe };

    }

  });

</script>

<style scoped>

  .sweeps-render {
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
