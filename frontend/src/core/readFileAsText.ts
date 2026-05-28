async function readFileAsText(file: File): Promise<string> {

  const res =
    new Promise<string>(
      (resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (): void => {
          resolve(reader.result as string);
        };
        reader.onerror = (): void => {
          reject(reader.error!);
        };
        reader.readAsText(file);
      }
    );

  return res;

}

export { readFileAsText };
