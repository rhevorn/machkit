export type MachKitAppearance = "system" | "light" | "dark";

export type MachKitPreferences = {
  locale: string;
  appearance: MachKitAppearance;
};

export type MachKitBridgeHandler = {
  postMessage: (request: {
    protocolVersion: 1;
    method: string;
    params?: Record<string, unknown>;
  }) => unknown | Promise<unknown>;
};

export type MachKitBridge = {
  bridge?: MachKitBridgeHandler;
};

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: MachKitBridge;
    };
    __MACHKIT__?: Readonly<MachKitPreferences>;
    __MACHKIT_APPLY_PREFERENCES__?: (next: Partial<MachKitPreferences>) => void;
    machkit?: unknown;
  }
}

export {};
