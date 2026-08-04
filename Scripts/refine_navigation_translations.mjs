import fs from "node:fs";

const file = new URL("../Resources/Localizable.xcstrings", import.meta.url);
const catalog = JSON.parse(fs.readFileSync(file, "utf8"));
const values = {
  "Sift": ["Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift", "Sift"],
  "Home": ["首页", "首頁", "ホーム", "홈", "Inicio", "Accueil", "Start", "Início", "Главная"],
  "Cleanup": ["垃圾清理", "垃圾清理", "クリーン", "정리", "Limpieza", "Nettoyage", "Bereinigen", "Limpeza", "Очистка"],
  "Uninstall": ["软件卸载", "軟體移除", "アンインストール", "제거", "Desinstalar", "Désinstaller", "Deinstallieren", "Desinstalar", "Удаление"],
  "Storage Analysis": ["存储分析", "儲存分析", "ストレージ", "저장 공간", "Almacenamiento", "Stockage", "Speicher", "Armazenamento", "Хранилище"],
  "Performance": ["性能监控", "效能監控", "パフォーマンス", "성능", "Rendimiento", "Performances", "Leistung", "Desempenho", "Ресурсы"],
  "Port Manager": ["端口管理", "連接埠管理", "ポート", "포트", "Puertos", "Ports", "Ports", "Portas", "Порты"],
  "Login Items & Extensions": ["登录项与扩展", "登入項目與擴充功能", "ログイン項目", "로그인 항목", "Inicio y extensiones", "Ouverture", "Autostart", "Inicialização", "Автозапуск"],
  "Settings": ["设置", "設定", "設定", "설정", "Ajustes", "Réglages", "Einstellungen", "Ajustes", "Настройки"],
  "Feedback": ["反馈", "意見回饋", "フィードバック", "피드백", "Comentarios", "Avis", "Feedback", "Feedback", "Отзыв"],
  "Follow System": ["跟随系统", "跟隨系統", "システム設定", "시스템 설정", "Seguir el sistema", "Selon le système", "Systemeinstellung", "Seguir o sistema", "Как в системе"]
};
const locales = ["zh-Hans", "zh-Hant", "ja", "ko", "es", "fr", "de", "pt-BR", "ru"];
for (const [key, translations] of Object.entries(values)) {
  const entry = catalog.strings[key];
  if (!entry) continue;
  entry.localizations ??= {};
  locales.forEach((locale, index) => {
    entry.localizations[locale] = { stringUnit: { state: "translated", value: translations[index] } };
  });
}
fs.writeFileSync(file, `${JSON.stringify(catalog, null, 2)}\n`);
