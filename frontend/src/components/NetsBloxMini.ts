// Cannibalized from:
// https://github.com/NetsBlox/Snap--Build-Your-Own-Blocks/blob/bacc96d08eac1348f6d89a87de2989934d96fbfc/embedded-api.js
// For some reason, the actual API wasn't working for me. --Jason B. (7/6/26)

type Deferred =
  { promise: Promise<unknown>
  , resolve: (_: unknown) => void
  ,  reject: (_: unknown) => void
  };

const requests: Record<number, Deferred> = {};

const dispatcher = new EventTarget();

const onMessage = (event: MessageEvent): void => {
  type Msg = { type: string, id: number | undefined, eventType: string | undefined, detail: unknown };
  const data = event.data as Msg;
  if (data.type === "reply") {
    const request = requests[data.id!];
    if (request !== undefined) {
      request.resolve(data);
      delete requests[data.id!]; // eslint-disable-line @typescript-eslint/no-dynamic-delete
    }
  } else if (data.type === "event") {
    const { eventType, detail } = data;
    dispatcher.dispatchEvent(new CustomEvent(eventType!, { detail }));
  }
};

window.addEventListener("message", onMessage, false);

async function getNetsBUsername(iframe: Window): Promise<string | null> {
  const reqData = { id: undefined, type: "get-username" };
  const data = await reqReply(reqData, iframe) as { username: string | null };
  return data.username;
}

async function getNetsBProjectXML(iframe: Window): Promise<string | null> {
  const reqData = { id: undefined, type: "export-project" };
  const data = await reqReply(reqData, iframe) as { xml: string | null };
  return data.xml;
}

async function reqReply( reqData: { id: number | undefined, type: string }
                       , iframeWindow: Window): Promise<unknown> {

  const id = Date.now() + Math.floor(Math.random() * 1000); // Could just use a counter....

  const deferred = defer();
  requests[id] = deferred;
  reqData.id = id;
  iframeWindow.postMessage(reqData, "*");

  setTimeout(
    () => {
      const def = requests[id];
      if (def) {
        def.reject(new Error("Timeout Exceeded"));
        delete requests[id]; // eslint-disable-line @typescript-eslint/no-dynamic-delete
      }
    }
  , 5000
  );

  return deferred.promise;

}

function defer(): Deferred {
  const deferred =
    { resolve: (_: unknown): void => {}
    ,  reject: (_: unknown): void => {}
    , promise: new Promise(() => {})
    };
  deferred.promise =
    new Promise(
      (resolve, reject) => {
        deferred.resolve = resolve;
        deferred.reject  = reject;
      }
    );
  return deferred;
};

export { getNetsBProjectXML, getNetsBUsername };
