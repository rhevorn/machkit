import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { EditorView } from "@codemirror/view";
import { sift } from "@/runtime/sift.js";

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
  const preferences = useSyncExternalStore(sift.subscribePreferences, sift.getPreferences, sift.getPreferences);
  const systemDark = useSystemDark();
  return preferences.appearance === "dark" || (preferences.appearance !== "light" && systemDark);
}

export function useSiftEditorTheme() {
  const dark = useEditorDark();

  return useMemo(
    () =>
      EditorView.theme(
        {
          "&": {
            backgroundColor: "var(--sift-field)",
            color: "var(--sift-text)",
          },
          ".cm-content": {
            caretColor: "var(--sift-accent)",
          },
          ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: "var(--sift-accent)",
          },
          ".cm-placeholder": {
            color: "var(--sift-tertiary)",
          },
          ".cm-gutters": {
            backgroundColor: "var(--sift-field)",
            color: "var(--sift-tertiary)",
            border: "none",
          },
          ".cm-activeLine, .cm-activeLineGutter": {
            backgroundColor: "color-mix(in srgb, var(--sift-text) 4%, transparent)",
          },
          "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection": {
            backgroundColor: "color-mix(in srgb, var(--sift-accent) 22%, transparent) !important",
          },
        },
        { dark },
      ),
    [dark],
  );
}
