import { watch, type Ref } from "vue";

function setTitle(title: Ref<string> | string): void {
  watch(
    () => (typeof title === "string" ? title : title.value),
    (val) => { document.title = (val !== "") ? `${val} | zócalo` : "zócalo"; },
    { immediate: true }
  );
}

export { setTitle };
