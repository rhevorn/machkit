import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { EditorView } from "@codemirror/view";
import { machkit } from "@/runtime/machkit.js";

function useSystemDark() {
  const [systemDark, setSystemDark] = useState(
    () => typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches,
  );

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setSystemDark(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  return systemDark;
}

export function useEditorDark() {
  const preferences = useSyncExternalStore(machkit.subscribePreferences, machkit.getPreferences, machkit.getPreferences);
  const systemDark = useSystemDark();
  return preferences.appearance === "dark" || (preferences.appearance !== "light" && systemDark);
}

export function useMachKitEditorTheme() {
  const dark = useEditorDark();

  return useMemo(
    () =>
      EditorView.theme(
        {
          "&": {
            backgroundColor: "var(--machkit-field)",
            color: "var(--machkit-text)",
          },
          ".cm-content": {
            caretColor: "var(--machkit-accent)",
          },
          ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: "var(--machkit-accent)",
          },
          ".cm-placeholder": {
            color: "var(--machkit-tertiary)",
          },
          ".cm-gutters": {
            backgroundColor: "var(--machkit-field)",
            color: "var(--machkit-tertiary)",
            border: "none",
          },
          ".cm-activeLine, .cm-activeLineGutter": {
            backgroundColor: "color-mix(in srgb, var(--machkit-text) 4%, transparent)",
          },
          "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection": {
            backgroundColor: "color-mix(in srgb, var(--machkit-accent) 22%, transparent) !important",
          },
        },
        { dark },
      ),
    [dark],
  );
}
