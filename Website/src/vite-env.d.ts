/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_RELEASE_TAG?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
