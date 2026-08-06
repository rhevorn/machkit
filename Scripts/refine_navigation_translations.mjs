import fs from "node:fs";
import path from "node:path";

const file = new URL("../Resources/Localizable.xcstrings", import.meta.url);
const root = path.resolve(import.meta.dirname, "..");
const catalog = JSON.parse(fs.readFileSync(file, "utf8"));
const values = {
  "Memory Usage": ["内存使用量", "記憶體使用量", "メモリ使用量", "메모리 사용량", "Uso de memoria", "Utilisation de la mémoire", "Speichernutzung", "Uso de memória", "Использование памяти"],
  "Critical": ["严重", "嚴重", "重大", "위험", "Crítico", "Critique", "Kritisch", "Crítico", "Критическое"],
  "Sift": ["Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift"],
  "Home": ["首页", "首頁", "ホーム", "홈", "Inicio", "Accueil", "Start", "Início", "Главная"],
  "Cleanup": ["垃圾清理", "垃圾清理", "クリーン", "정리", "Limpieza", "Nettoyage", "Bereinigen", "Limpeza", "Очистка"],
  "Apps": ["应用", "應用程式", "アプリ", "앱", "Aplicaciones", "Applications", "Apps", "Aplicativos", "Приложения"],
  "Storage": ["存储", "儲存", "ストレージ", "저장 공간", "Almacenamiento", "Stockage", "Speicher", "Armazenamento", "Хранилище"],
  "Performance": ["性能监控", "效能監控", "パフォーマンス", "성능", "Rendimiento", "Performances", "Leistung", "Desempenho", "Ресурсы"],
  "Ports": ["端口", "連接埠", "ポート", "포트", "Puertos", "Ports", "Ports", "Portas", "Порты"],
  "System": ["系统", "系統", "システム", "시스템", "Sistema", "Système", "System", "Sistema", "Система"],
  "Settings": ["设置", "設定", "設定", "설정", "Ajustes", "Réglages", "Einstellungen", "Ajustes", "Настройки"],
  "Feedback": ["反馈", "意見回饋", "フィードバック", "피드백", "Comentarios", "Avis", "Feedback", "Feedback", "Отзыв"],
  "Follow System": ["跟随系统", "跟隨系統", "システム設定", "시스템 설정", "Seguir el sistema", "Selon le système", "Systemeinstellung", "Seguir o sistema", "Как в системе"]
};
const locales = ["zh-Hans", "zh-Hant", "ja", "ko", "es", "fr", "de", "pt-BR", "ru"];
for (const [key, translations] of Object.entries(values)) {
  const entry = catalog.strings[key] ??= {};
  entry.localizations ??= {};
  locales.forEach((locale, index) => {
    entry.localizations[locale] = { stringUnit: { state: "translated", value: translations[index] } };
  });
}

function swiftFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) return swiftFiles(target);
    return entry.isFile() && entry.name.endsWith(".swift") ? [target] : [];
  });
}

// Runtime localization helpers are invisible to Xcode's extractor. Keep only
// catalog keys that still occur as Swift string literals, and remove genuinely
// dead stale entries so the catalog remains warning-free without hiding debris.
const referencedLiterals = new Set();
for (const sourceDirectory of [path.join(root, "App/Sources"), path.join(root, "Sources")]) {
  for (const sourceFile of swiftFiles(sourceDirectory)) {
    const source = fs.readFileSync(sourceFile, "utf8");
    for (const match of source.matchAll(/"((?:\\.|[^"\\])*)"/g)) {
      try {
        referencedLiterals.add(JSON.parse(`"${match[1]}"`));
      } catch {
        // Ignore interpolated or otherwise non-JSON Swift literals.
      }
    }
  }
}
for (const [key, entry] of Object.entries(catalog.strings)) {
  if (entry.extractionState !== "stale") continue;
  if (referencedLiterals.has(key)) entry.extractionState = "manual";
  else delete catalog.strings[key];
}

// Removed features: do not retain obsolete translations as manual entries.
for (const key of [
  "Allow paths, file types, sizes, and process details to be sent for analysis",
  "Share Technical Metadata",
  "Uninstall",
  "Storage Analysis",
  "Port Manager",
  "Login Items & Extensions",
  ""
]) {
  delete catalog.strings[key];
}
fs.writeFileSync(file, `${JSON.stringify(catalog, null, 2)}\n`);
