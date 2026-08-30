import { useMemo } from "react";
import { CaretRightIcon } from "@phosphor-icons/react";
import { ToolContent, ToolPage } from "@/ui/index.js";
import { useLocale, useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { listTools } from "@/tools-catalog.js";
import { homeMessages } from "@/home-messages.js";
import "./styles.css";

function toolHref(path: string): string {
  const query = window.location.search;
  return query ? `${path}${query}` : path;
}

function HomePage() {
  const locale = useLocale();
  const text = useToolMessages(homeMessages);
  const tools = useMemo(() => listTools(locale), [locale]);

  return (
    <ToolPage title={text.title} adaptiveHeight={false}>
      <ToolContent className="mx-auto flex h-full w-full max-w-[720px] flex-col gap-6 overflow-y-auto px-6 py-10">
        <header className="flex flex-col gap-2">
          <p className="text-[11px] font-semibold tracking-[0.04em] text-accent uppercase">
            MachKit · Web
          </p>
          <h1 className="text-[28px] leading-tight font-semibold tracking-[-0.03em] text-foreground">
            {text.title}
          </h1>
          <p className="max-w-xl text-[13px] leading-relaxed text-secondary">{text.subtitle}</p>
        </header>

        <section className="flex flex-col gap-2" aria-label={text.tools}>
          {tools.map((tool) => (
            <a
              key={tool.id}
              href={toolHref(tool.href)}
              className="group flex items-center gap-4 rounded-panel border border-border bg-field px-4 py-3.5 no-underline transition-[border-color,background-color] hover:border-accent/40 hover:bg-muted"
            >
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-semibold text-foreground">{tool.title}</div>
                {tool.description ? (
                  <p className="mt-1 text-[12px] leading-relaxed text-secondary">{tool.description}</p>
                ) : null}
                <p className="mt-1 font-mono text-[11px] text-tertiary">{tool.id}</p>
              </div>
              <span className="flex shrink-0 items-center gap-1 text-[12px] font-medium text-accent opacity-80 group-hover:opacity-100">
                {text.open}
                <CaretRightIcon size={14} weight="bold" />
              </span>
            </a>
          ))}
        </section>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<HomePage />, { name: "home" });
