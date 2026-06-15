declare class GGBApplet {
  public constructor(params: Record<string, unknown>, version: string, views: Record<string, unknown>)
  public getBase64(): Promise<string>;
  public getPNGBase64(x: number, isWhatever: boolean, something: string | undefined): Promise<string>;
  public inject(): void;
  public setBase64(input: string): void;
  public setHTML5Codebase(url: string): void;
  public setPreviewImage(base64: string, loadingPath: string, playPath: string): void;
}

declare const ggbApplet: Record<string, unknown>;
