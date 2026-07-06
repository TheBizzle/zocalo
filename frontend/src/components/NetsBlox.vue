<template>
  <iframe ref="iframe" id="nets-frame" class="netsblox-render" src="https://editor.netsblox.org/"
          width="100%" height="100%">
  </iframe>
</template>

<script lang="ts">

  import { defineComponent, onMounted, onUnmounted, ref, watch } from "vue";
  import { useRoute                                            } from "vue-router";

  import type { ExportData } from "@/core/ExportData.ts";
  import { initUsername    } from "@/core/StudentAuth.ts";

  import { getNetsBProjectXML, getNetsBUsername } from "./NetsBloxMini.ts";

  export default defineComponent({
    name:  "NetsBlox"
  , props: { galleryID:     { type:  String, required: true }
           , loadedContent: { type:  String, required: true }
           , shouldExport:  { type: Boolean, required: true }
           }
  , emits: ["export-data", "hide-filler"]
  , setup(props, { emit }) {

      useRoute();

      emit("hide-filler");

      const iframe = ref<HTMLIFrameElement | null>(null);

      onMounted(
        async () => {
          window.addEventListener("message", onMessage);
          await initNetsBlox();
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

      const peskyLoop = // Load the waiting data, once NetsBlox is loaded
        setInterval(
          () => { iframe.value?.contentWindow?.postMessage({ type: "get-username" }, "*"); }
        , 50
        );

      let hasLoaded = false;
      let waitingData: Record<string, string> | null = null;

      watch(
        () => props.loadedContent
      , async (content) => {
          if (hasLoaded) {
            iframe.value?.contentWindow?.postMessage(content, "*");
          } else {
            waitingData = JSON.parse(content) as Record<string, string>;
          }
        }
      );

      async function initNetsBlox(): Promise<void> {

        const params = new URLSearchParams(window.location.search);

        const starterProject = params.get("starterProject") ?? "https://editor.netsblox.org/?";
        const projectName    = params.get(   "ProjectName") ?? "";

        const nbUsername    = (await getNetsBUsername(iframe.value!.contentWindow!)) ?? null;
        const paramUsername = params.get("Username");
        const username      = initUsername(nbUsername ?? paramUsername);

        const synthParams =
         new URLSearchParams(
           { Username:    username
           , ProjectName: projectName
           , editMode:    true.toString()
           , hash:        props.galleryID
           , gallery:     window.location.origin
           }
         );

        iframe.value!.src = `${starterProject}&${synthParams}`;

      }

      function onMessage(event: MessageEvent): void {

        if (event.source === iframe.value?.contentWindow) {
          const data = event.data as { type: string };
          switch (data.type) {

            case "import-project":
              const msg = { ...data, type: "import" };
              if (hasLoaded) {
                iframe.value.contentWindow?.postMessage(msg, "*");
              } else {
                waitingData = msg;
              }
              break;

            case "reply":

              clearInterval(peskyLoop);

              const  dMsg = { key: "domain"      , value: window.location.origin, type: "set-variable" };
              const lhMsg = { key: "locationHash", value:        props.galleryID, type: "set-variable" };

              iframe.value.contentWindow?.postMessage( dMsg, "*");
              iframe.value.contentWindow?.postMessage(lhMsg, "*");

              if (waitingData !== null) {
                iframe.value.contentWindow?.postMessage(waitingData, "*");
                waitingData = null;
              }

              hasLoaded = true;

            default:
              console.log("Ignoring message:", data.type, event);

          }
        }
      }

      async function fetchStarter(): Promise<void> {
        // Does not currently do anything.  The old code was trying to grab something called a "starter"
        // from the query params.  Yet... that can't be right... right?  IDK. --Jason B. (7/5/26)

        // const res = await fetch(`/api/galleries/${props.galleryID}/student/starter-config`);
        // if (res.ok) {
        //  console.warn("Starter", await res.text());
        // }
      }

      async function exportData(): Promise<ExportData | undefined> {
        const data        = (await getNetsBProjectXML(iframe.value!.contentWindow!)) ?? "";
        const baseBase64  = getThumbnailFromXML(data);
        const imageBase64 = baseBase64.slice(baseBase64.indexOf(",") + 1);
        return { data, mimeType: "image/png", imageBase64 };
      }

      function getThumbnailFromXML(xml: string): string {
        const tagName    = "thumbnail";
        const openTag    = `<${tagName}>`;
        const startIndex = xml.indexOf(openTag) + openTag.length;
        const endIndex   = xml.indexOf(`</${tagName}>`);
        return xml.substring(startIndex, endIndex);
      }

      return { iframe };

    }

  });

</script>

<style scoped>

  .hiding {
    display: none;
    padding: 0;
  }

  .nets-frame {
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

  .nets-frame {
    border: 2px solid black;
    margin-left: -2px;
  }

</style>
