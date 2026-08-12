import { convertCodec } from "./codec.js";

self.onmessage = async ({ data }) => {
  const { id, parameters } = data;
  try {
    const result = await convertCodec(parameters);
    self.postMessage({ id, result });
  } catch (error) {
    self.postMessage({
      id,
      result: {
        ok: false,
        value: "",
        error: error instanceof Error ? error.message : "unsupported",
      },
    });
  }
};
