import React from "react";
import { CheckCircle, WarningCircle } from "@phosphor-icons/react";
import { cn } from "@/lib/utils.js";
import { useLocale } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { ToolInfoButton } from "./button.jsx";

const copiedLabels = {
  en: { success: "Copied", failure: "Copy failed" },
  "zh-Hans": { success: "已复制", failure: "复制失败" },
  "zh-Hant": { success: "已複製", failure: "複製失敗" },
  ja: { success: "コピーしました", failure: "コピーできませんでした" },
  ko: { success: "복사됨", failure: "복사 실패" },
  es: { success: "Copiado", failure: "Error al copiar" },
  fr: { success: "Copié", failure: "Échec de la copie" },
  de: { success: "Kopiert", failure: "Kopieren fehlgeschlagen" },
  "pt-BR": { success: "Copiado", failure: "Falha ao copiar" },
  ru: { success: "Скопировано", failure: "Не удалось скопировать" },
};

export function ToolPage({ title, info, adaptiveHeight = true, children }) {
  const pageRef = React.useRef(null);

  React.useEffect(() => {
    document.title = title;
  }, [title]);

  React.useEffect(() => {
    if (!adaptiveHeight || !machkit.isEmbedded || typeof ResizeObserver === "undefined") return undefined;

    const content = pageRef.current?.querySelector(":scope > [data-machkit-tool-content]")
      ?? pageRef.current;
    if (!content) return undefined;

    let animationFrame = 0;
    let lastHeight = 0;
    const measure = () => {
      window.cancelAnimationFrame(animationFrame);
      animationFrame = window.requestAnimationFrame(() => {
        const height = Math.ceil(Math.max(content.scrollHeight, content.getBoundingClientRect().height));
        if (Math.abs(height - lastHeight) < 2) return;
        lastHeight = height;
        machkit.fitContentHeight(height);
      });
    };

    const observer = new ResizeObserver(measure);
    observer.observe(content);
    measure();
    document.fonts?.ready.then(measure);

    return () => {
      observer.disconnect();
      window.cancelAnimationFrame(animationFrame);
    };
  }, [adaptiveHeight]);

  return (
    <main ref={pageRef} className="relative flex h-full min-h-full w-full min-w-0 flex-col overflow-hidden bg-surface font-sans text-[13px] text-foreground">
      {info ? (
        <div className="absolute top-2 right-5 z-20">
          <ToolInfoButton info={info} />
        </div>
      ) : null}
      {children}
      <CopyFeedbackToast />
    </main>
  );
}

function CopyFeedbackToast() {
  const locale = useLocale();
  const [toast, setToast] = React.useState(null);
  const timeoutRef = React.useRef(0);

  React.useEffect(() => {
    const showToast = (event) => {
      window.clearTimeout(timeoutRef.current);
      setToast({ id: Date.now(), ok: event.detail?.ok !== false });
      timeoutRef.current = window.setTimeout(() => setToast(null), 1800);
    };
    window.addEventListener("machkit:copy-result", showToast);
    return () => {
      window.removeEventListener("machkit:copy-result", showToast);
      window.clearTimeout(timeoutRef.current);
    };
  }, []);

  if (!toast) return null;
  const labels = copiedLabels[locale] || copiedLabels.en;

  return (
    <div
      key={toast.id}
      role="status"
      aria-live="polite"
      className={cn(
        "pointer-events-none fixed bottom-5 left-1/2 z-[100] inline-flex -translate-x-1/2 items-center gap-2 rounded-full border px-3.5 py-2 text-xs font-medium shadow-popover animate-in fade-in-0 slide-in-from-bottom-2 duration-150",
        toast.ok ? "border-border bg-foreground text-surface" : "border-danger/25 bg-danger text-white",
      )}
    >
      {toast.ok ? <CheckCircle size={16} weight="fill" /> : <WarningCircle size={16} weight="fill" />}
      {toast.ok ? labels.success : labels.failure}
    </div>
  );
}
