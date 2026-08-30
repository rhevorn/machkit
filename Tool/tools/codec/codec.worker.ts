import { convertCodec, type ConvertCodecParams, type ConvertCodecResult } from "./codec.js";

type WorkerRequest = {
  id: unknown;
  parameters: ConvertCodecParams;
};

self.onmessage = async ({ data }: MessageEvent<WorkerRequest>) => {
  const { id, parameters } = data;
  try {
    const result: ConvertCodecResult = await convertCodec(parameters);
    self.postMessage({ id, result });
  } catch (error) {
    self.postMessage({
      id,
      result: {
        ok: false,
        value: "",
        error: error instanceof Error ? error.message : "unsupported",
      } satisfies ConvertCodecResult,
    });
  }
};
