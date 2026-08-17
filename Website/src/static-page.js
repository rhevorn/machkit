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
