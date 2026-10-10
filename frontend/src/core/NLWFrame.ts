type NLWMessageEvent = MessageEvent<{ type: string }>;

 // eslint-disable-next-line @typescript-eslint/no-explicit-any
type Payload = Record<string, any> & { type: string };

type FrameResponse = (x: Payload) => void;

type   AnswerableMessage = { payload: Payload, type: "answerable", resolver: FrameResponse };
type UnanswerableMessage = { payload: Payload, type: "unanswerable" };

type QueuedMessage = AnswerableMessage | UnanswerableMessage;

type  ExportCodeResponse = { export:             string, type: "nlw-export-code-results"  };
type ExportModelResponse = { export: { result: string }, type: "nlw-export-model-results" };
type  ExportViewResponse = { base64:             string, type: "nlw-view"                 };
type ExportWorldResponse = { export:             string, type: "nlw-export-world-results" };
type ImportWorldResponse = { world:              string, type: "nlw-import-world"         };

const payloadTypeToResponseType: Record<string, string> = {
  "nlw-export-code":  "nlw-export-code-results"
, "nlw-export-model": "nlw-export-model-results"
, "nlw-export-world": "nlw-export-world-results"
, "nlw-request-view": "nlw-view"
, "nlw-load-model":   "nlw-is-loaded"
, "nlw-import-world": "nlw-world-imported"
};

class NLWFrame {

  private readonly frame: Window;
  private isReady = false;
  private readonly msgQueue: Array<QueuedMessage> = [];

  private readonly resolvers: Record<string, Array<FrameResponse>> = {
    "nlw-is-loaded":            [(): void => { void this.onFrameLoad(); }]
  , "nlw-export-code-results":  []
  , "nlw-export-model-results": []
  , "nlw-export-world-results": []
  , "nlw-view":                 []
  , "nlw-world-imported":       []
  };

  public constructor(frame: HTMLIFrameElement) {
    this.frame = frame.contentWindow!;

    window.addEventListener(
      "message"
    , (e) => {
        if (e.source === this.frame) {
          const event = e as NLWMessageEvent;
          event.stopImmediatePropagation();
          event.preventDefault();

          switch (event.data.type) {
            case "nlw-is-loaded":
            case "nlw-export-code-results":
            case "nlw-export-model-results":
            case "nlw-export-world-results":
            case "nlw-view":
            case "nlw-world-imported": {
              const resolvers = this.resolvers[event.data.type] ?? [];
              if (resolvers.length > 0) {
                const resolver = (resolvers.shift() ?? ((): void => {}));
                setTimeout(() => { resolver(event.data); }, 40);
              } else {
                console.warn("No handler waiting for:", event.data.type);
              }
              break;
            }
            case "nlw-resize":
            case "nlw-set-hash": {
              break;
            }
            default: {
              console.warn("Unknown message", event);
            }
          }
        }
      }
    , { capture: true }
    );
  }

  public async enqueueExportCode(): Promise<ExportCodeResponse> {
    return this.enqueue({ type: "nlw-export-code" });
  }

  public async enqueueExportModel(): Promise<ExportModelResponse> {
    return this.enqueue({ type: "nlw-export-model" });
  }

  public async enqueueExportWorld(): Promise<ExportWorldResponse> {
    return this.enqueue({ type: "nlw-export-world" });
  }

  public async enqueueExportView(): Promise<ExportViewResponse> {
    return this.enqueue({ type: "nlw-request-view" });
  }

  public async enqueueImportWorld(world: string): Promise<ImportWorldResponse> {
    console.warn("Importing world...");
    return this.enqueue({ world, type: "nlw-import-world" });
  }

  public enqueueUnanswerable(payload: Payload): void {
    this.enqueueMsg({ payload, type: "unanswerable" });
  }

  private async enqueue<ResponseType>(payload: Payload): Promise<ResponseType> {
    return new Promise<ResponseType>(
      (resolve) => {
        const resolver               = resolve as FrameResponse;
        const msg: AnswerableMessage = { payload, type: "answerable", resolver };
        this.enqueueMsg(msg);
      }
    );
  }

  private enqueueMsg(msg: QueuedMessage): void {
    if (!this.isReady) {
      this.msgQueue.push(msg);
    } else {
      void this.processMessage(msg);
    }
  }

  private async onFrameLoad(): Promise<void> {
    this.isReady = true;
    while (this.msgQueue.length > 0) {
      await this.processMessage(this.msgQueue.shift()!);
    }
  }

  private async processMessage(msg: QueuedMessage): Promise<void> {

    switch (msg.type) {

      case "unanswerable": {
        this.frame.postMessage(msg.payload, "*");
        return Promise.resolve();
      }

      case "answerable": {
        const responseType = payloadTypeToResponseType[msg.payload.type];
        if (responseType === undefined) {
          console.error("Cannot associate this NLW message with any response type", msg);
          return Promise.resolve();
        } else {
          return new Promise<void>(
            (resolve) => {
              const f = (x: Payload): void => {
                msg.resolver(x);
                resolve();
              };
              this.resolvers[responseType]!.push(f);
              this.frame.postMessage(msg.payload, "*");
            }
          );
        }
      }

      default: {
        console.error("Impossible queued message kind", msg);
        return Promise.resolve();
      }

    }

  }

}

export { NLWFrame };
