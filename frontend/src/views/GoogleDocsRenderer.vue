<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="gdocs-render" :class="dynamicallyHide" v-html="sanitizedContent"></div>
</template>

<script lang="ts">

  import { defineComponent, ref, watch } from "vue";
  import { useRoute                    } from "vue-router";

  import { sanitizeHTML } from "@/core/sanitizeHTML.ts";

  export default defineComponent({

    name:  "GoogleDocsRenderer"
  , props: { loadedContent: { type: String, required: true } }
  , computed: {
      dynamicallyHide() {
        return { "hiding": this.loadedContent === "" };
      }
    }

  , setup(props) {
      useRoute();
      const sanitizedContent = ref("");
      watch(
        () => props.loadedContent
      , async (content) => {
          console.log(content);
          sanitizedContent.value = sanitizeHTML(content);
        }
      );
      return { sanitizedContent };
    }

  });

</script>

<style scoped>

  .gdocs-render {
    background:  white;
    color:       var(--clr-ink);
    font-family: Arial, sans-serif;
    font-size:   11pt;
    line-height: 1.15;
    padding:     1rem 1.25rem;
    overflow:    auto;
  }

  .gdocs-render h1 { font-size: 20pt; font-weight: 400; margin: 0 0 12px; }
  .gdocs-render h2 { font-size: 16pt; font-weight: 400; margin: 16px 0 8px; }
  .gdocs-render h3 { font-size: 14pt; font-weight: 400; margin: 12px 0 6px; }

  .gdocs-render h4, .gdocs-render h5, .gdocs-render h6 {
    font-size:   11pt;
    font-weight: 700;
    margin:      8px 0 4px;
  }

  .gdocs-render p {
    margin: 0 0 8px;
  }

  .gdocs-render ul, .gdocs-render ol {
    margin:       0 0 8px;
    padding-left: 2em;
  }

  .gdocs-render li {
    margin-bottom: 4px;
  }

  .gdocs-render table {
    border-collapse: collapse;
    margin-bottom:   12px;
    width:           100%;
  }

  .gdocs-render td, .gdocs-render th {
    border:         1px solid var(--clr-primary);
    padding:        6px 10px;
    vertical-align: top;
  }

  .gdocs-render th {
    background:  white;
    font-weight: 500;
  }

  .gdocs-render b, .gdocs-render strong {
    font-weight: 700;
  }

  .gdocs-render a {
    color: #1155cc;
  }

  .gdocs-render hr {
    border:     none;
    border-top: 1px solid var(--clr-border-3);
    margin:     16px 0;
  }

  .gdocs-render img {
    max-width: 100%;
  }

  .gdocs-render .title {
    font-family: Georgia, serif;
    font-size:   26pt;
    font-weight: 400;
  }

  .gdocs-render .subtitle {
    font-size: 15pt;
    color:     var(--clr-accent);
  }

  .hiding {
    display: none;
    padding: 0;
  }

</style>
