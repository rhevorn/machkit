const themeKey = "machkit-website-theme";
const themeButton = document.querySelector("[data-theme-toggle]");

themeButton?.addEventListener("click", () => {
  const current = document.documentElement.dataset.theme === "dark" ? "dark" : "light";
  const next = current === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  document.documentElement.style.colorScheme = next;
  document.querySelector('meta[name="theme-color"]')?.setAttribute(
    "content",
    next === "dark" ? "#101214" : "#f4f5f7",
  );
  window.localStorage.setItem(themeKey, next);
});

const screenTabs = Array.from(document.querySelectorAll<HTMLButtonElement>("[data-screen-tab]"));
const screenPanels = Array.from(document.querySelectorAll<HTMLElement>("[data-screen-panel]"));

function selectScreen(tab: HTMLButtonElement, moveFocus = false) {
  const key = tab.dataset.screenTab;
  if (!key) return;

  for (const candidate of screenTabs) {
    const active = candidate === tab;
    candidate.classList.toggle("is-active", active);
    candidate.setAttribute("aria-selected", String(active));
    candidate.tabIndex = active ? 0 : -1;
  }
  for (const panel of screenPanels) {
    panel.hidden = panel.dataset.screenPanel !== key;
  }
  if (moveFocus) tab.focus();
}

for (const [index, tab] of screenTabs.entries()) {
  tab.addEventListener("click", () => selectScreen(tab));
  tab.addEventListener("keydown", (event) => {
    let nextIndex: number | undefined;
    if (event.key === "ArrowRight") nextIndex = (index + 1) % screenTabs.length;
    if (event.key === "ArrowLeft") nextIndex = (index - 1 + screenTabs.length) % screenTabs.length;
    if (event.key === "Home") nextIndex = 0;
    if (event.key === "End") nextIndex = screenTabs.length - 1;
    if (nextIndex === undefined) return;
    event.preventDefault();
    const nextTab = screenTabs[nextIndex];
    if (nextTab) selectScreen(nextTab, true);
  });
}
