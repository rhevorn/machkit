const handlers = () => window.webkit?.messageHandlers;

export const sift = Object.freeze({
  isEmbedded: Boolean(window.webkit?.messageHandlers),

  post(name, payload = null) {
    const handler = handlers()?.[name];
    if (!handler || typeof handler.postMessage !== "function") return false;
    handler.postMessage(payload);
    return true;
  },

  copy(text) {
    if (this.post("copy", { text })) return Promise.resolve(true);
    return navigator.clipboard.writeText(text).then(() => true);
  },

  close() {
    return this.post("closeTool");
  },
});
