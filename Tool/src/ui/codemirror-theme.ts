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
  { tag: t.propertyName, color: "#a16207", class: "json-cm-key" },
  { tag: t.string, color: "#a31515" },
  { tag: t.number, color: "#098658" },
  { tag: t.bool, color: "#0000ff" },
  { tag: t.null, color: "#0000ff" },
  { tag: t.keyword, color: "#0000ff" },
  { tag: t.punctuation, color: "#000000" },
  { tag: t.bracket, color: "#000000" },
  { tag: t.squareBracket, color: "#000000" },
  { tag: t.brace, color: "#000000" },
  { tag: t.separator, color: "#000000" },
  { tag: t.invalid, color: "#cd3131" },
]);

const darkHighlight = HighlightStyle.define([
  { tag: t.propertyName, color: "#e5c07b", class: "json-cm-key" },
  { tag: t.string, color: "#ce9178" },
  { tag: t.number, color: "#b5cea8" },
  { tag: t.bool, color: "#569cd6" },
  { tag: t.null, color: "#569cd6" },
  { tag: t.keyword, color: "#569cd6" },
  { tag: t.punctuation, color: "#d4d4d4" },
  { tag: t.bracket, color: "#d4d4d4" },
  { tag: t.squareBracket, color: "#d4d4d4" },
  { tag: t.brace, color: "#d4d4d4" },
  { tag: t.separator, color: "#d4d4d4" },
  { tag: t.invalid, color: "#f44747" },
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
