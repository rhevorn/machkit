import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";
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

const lightHighlight = HighlightStyle.define([
  { tag: t.propertyName, color: "#087fff" },
  { tag: t.string, color: "#1a7f37" },
  { tag: t.number, color: "#9a6700" },
  { tag: t.bool, color: "#8250df" },
  { tag: t.null, color: "#8250df" },
  { tag: t.keyword, color: "#8250df" },
  { tag: t.punctuation, color: "#696b73" },
  { tag: t.bracket, color: "#696b73" },
  { tag: t.squareBracket, color: "#696b73" },
  { tag: t.brace, color: "#696b73" },
  { tag: t.separator, color: "#93959d" },
  { tag: t.invalid, color: "#d83b3b" },
]);

const darkHighlight = HighlightStyle.define([
  { tag: t.propertyName, color: "#6cb6ff" },
  { tag: t.string, color: "#7ee787" },
  { tag: t.number, color: "#e3b341" },
  { tag: t.bool, color: "#d2a8ff" },
  { tag: t.null, color: "#d2a8ff" },
  { tag: t.keyword, color: "#d2a8ff" },
  { tag: t.punctuation, color: "#a2a2a8" },
  { tag: t.bracket, color: "#a2a2a8" },
  { tag: t.squareBracket, color: "#a2a2a8" },
  { tag: t.brace, color: "#a2a2a8" },
  { tag: t.separator, color: "#707076" },
  { tag: t.invalid, color: "#ff6961" },
]);

export function useMachKitEditorTheme() {
  const dark = useEditorDark();

  return useMemo(
    () => [
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
      syntaxHighlighting(dark ? darkHighlight : lightHighlight),
    ],
    [dark],
  );
}
