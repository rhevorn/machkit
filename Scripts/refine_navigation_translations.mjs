import fs from "node:fs";
import path from "node:path";

const file = new URL("../Resources/Localizable.xcstrings", import.meta.url);
const root = path.resolve(import.meta.dirname, "..");
const catalog = JSON.parse(fs.readFileSync(file, "utf8"));
const values = {
  "Memory Usage": ["内存使用量", "記憶體使用量", "メモリ使用量", "메모리 사용량", "Uso de memoria", "Utilisation de la mémoire", "Speichernutzung", "Uso de memória", "Использование памяти"],
  "Critical": ["严重", "嚴重", "重大", "위험", "Crítico", "Critique", "Kritisch", "Crítico", "Критическое"],
  "Save": ["保存", "儲存", "保存", "저장", "Guardar", "Enregistrer", "Sichern", "Salvar", "Сохранить"],
  "API Key saved": ["API 密钥已保存", "API 金鑰已儲存", "API キーを保存しました", "API 키를 저장했습니다", "Clave API guardada", "Clé API enregistrée", "API-Schlüssel gespeichert", "Chave de API salva", "Ключ API сохранён"],
  "API Key removed": ["API 密钥已移除", "API 金鑰已移除", "API キーを削除しました", "API 키를 삭제했습니다", "Clave API eliminada", "Clé API supprimée", "API-Schlüssel entfernt", "Chave de API removida", "Ключ API удалён"],
  "Unable to save API Key (error %d).": ["无法保存 API 密钥（错误 %d）。", "無法儲存 API 金鑰（錯誤 %d）。", "API キーを保存できません（エラー %d）。", "API 키를 저장할 수 없습니다(오류 %d).", "No se pudo guardar la clave API (error %d).", "Impossible d’enregistrer la clé API (erreur %d).", "API-Schlüssel konnte nicht gespeichert werden (Fehler %d).", "Não foi possível salvar a chave de API (erro %d).", "Не удалось сохранить ключ API (ошибка %d)."],
  "No models added": ["尚未添加模型", "尚未加入模型", "モデルが追加されていません", "추가된 모델 없음", "No hay modelos añadidos", "Aucun modèle ajouté", "Keine Modelle hinzugefügt", "Nenhum modelo adicionado", "Модели не добавлены"],
  "Add Model": ["添加模型", "加入模型", "モデルを追加", "모델 추가", "Añadir modelo", "Ajouter un modèle", "Modell hinzufügen", "Adicionar modelo", "Добавить модель"],
  "Add a model identifier supported by this endpoint": ["添加此 API 地址支持的模型标识符", "加入此 API 端點支援的模型識別碼", "このエンドポイントが対応するモデル識別子を追加します", "이 엔드포인트가 지원하는 모델 식별자 추가", "Añade un identificador de modelo compatible con este endpoint", "Ajoutez un identifiant de modèle pris en charge par ce point de terminaison", "Eine von diesem Endpunkt unterstützte Modellkennung hinzufügen", "Adicione um identificador de modelo compatível com este endpoint", "Добавьте идентификатор модели, поддерживаемый этим API-адресом"],
  "Model identifier": ["模型标识符", "模型識別碼", "モデル識別子", "모델 식별자", "Identificador del modelo", "Identifiant du modèle", "Modellkennung", "Identificador do modelo", "Идентификатор модели"],
  "Add": ["添加", "加入", "追加", "추가", "Añadir", "Ajouter", "Hinzufügen", "Adicionar", "Добавить"],
  "AI Cleanup Insight": ["AI 清理分析", "AI 清理分析", "AI クリーンアップ分析", "AI 정리 분석", "Análisis de limpieza con IA", "Analyse du nettoyage par IA", "KI-Bereinigungsanalyse", "Análise de limpeza por IA", "Анализ очистки с ИИ"],
  "Uses category totals and risk labels only; file contents are never sent": ["仅使用分类汇总和风险标签，绝不会发送文件内容", "僅使用分類總計和風險標籤，絕不會傳送檔案內容", "カテゴリ集計とリスクラベルのみを使用し、ファイル内容は送信しません", "카테고리 합계와 위험 레이블만 사용하며 파일 내용은 전송하지 않습니다", "Solo usa totales por categoría y etiquetas de riesgo; nunca envía el contenido de los archivos", "Utilise uniquement les totaux par catégorie et les niveaux de risque ; le contenu des fichiers n’est jamais envoyé", "Verwendet nur Kategoriesummen und Risikokennzeichnungen; Dateiinhalte werden nie gesendet", "Usa apenas totais por categoria e rótulos de risco; o conteúdo dos arquivos nunca é enviado", "Используются только итоги по категориям и метки риска; содержимое файлов не отправляется"],
  "Analyze with AI": ["使用 AI 分析", "使用 AI 分析", "AI で分析", "AI로 분석", "Analizar con IA", "Analyser avec l’IA", "Mit KI analysieren", "Analisar com IA", "Анализировать с ИИ"],
  "Analyze Again": ["重新分析", "重新分析", "もう一度分析", "다시 분석", "Analizar de nuevo", "Analyser à nouveau", "Erneut analysieren", "Analisar novamente", "Анализировать снова"],
  "Configure Base URL, API Key, and a model in Settings first.": ["请先在设置中配置 Base URL、API 密钥和模型。", "請先在設定中配置 Base URL、API 金鑰和模型。", "設定で Base URL、API キー、モデルを先に設定してください。", "설정에서 Base URL, API 키 및 모델을 먼저 구성하세요.", "Configura primero la URL base, la clave API y un modelo en Ajustes.", "Configurez d’abord l’URL de base, la clé API et un modèle dans Réglages.", "Konfigurieren Sie zuerst Basis-URL, API-Schlüssel und ein Modell in den Einstellungen.", "Configure primeiro a URL base, a chave de API e um modelo nos Ajustes.", "Сначала настройте базовый URL, ключ API и модель в Настройках."],
  "The configured Base URL is invalid.": ["配置的 Base URL 无效。", "配置的 Base URL 無效。", "設定された Base URL が無効です。", "구성된 Base URL이 올바르지 않습니다.", "La URL base configurada no es válida.", "L’URL de base configurée n’est pas valide.", "Die konfigurierte Basis-URL ist ungültig.", "A URL base configurada é inválida.", "Настроенный базовый URL недействителен."],
  "The AI service returned an unreadable response.": ["AI 服务返回了无法读取的响应。", "AI 服務傳回了無法讀取的回應。", "AI サービスから読み取れない応答が返されました。", "AI 서비스가 읽을 수 없는 응답을 반환했습니다.", "El servicio de IA devolvió una respuesta ilegible.", "Le service d’IA a renvoyé une réponse illisible.", "Der KI-Dienst hat eine unlesbare Antwort zurückgegeben.", "O serviço de IA retornou uma resposta ilegível.", "Сервис ИИ вернул нечитаемый ответ."],
  "API Key": ["API 密钥", "API 金鑰", "API キー", "API 키", "Clave API", "Clé API", "API-Schlüssel", "Chave de API", "Ключ API"],
  "Base URL": ["Base URL", "Base URL", "Base URL", "Base URL", "URL base", "URL de base", "Basis-URL", "URL base", "Базовый URL"],
  "Model": ["模型", "模型", "モデル", "모델", "Modelo", "Modèle", "Modell", "Modelo", "Модель"],
  "Model identifier used for AI requests": ["用于 AI 请求的模型标识符", "用於 AI 請求的模型識別碼", "AI リクエストに使用するモデル識別子", "AI 요청에 사용할 모델 식별자", "Identificador del modelo utilizado para solicitudes de IA", "Identifiant du modèle utilisé pour les requêtes d’IA", "Modellkennung für KI-Anfragen", "Identificador do modelo usado em solicitações de IA", "Идентификатор модели для запросов ИИ"],
  "OpenAI-compatible API endpoint": ["兼容 OpenAI 的 API 地址", "與 OpenAI 相容的 API 端點", "OpenAI 互換の API エンドポイント", "OpenAI 호환 API 엔드포인트", "Endpoint de API compatible con OpenAI", "Point de terminaison d’API compatible avec OpenAI", "OpenAI-kompatibler API-Endpunkt", "Endpoint de API compatível com OpenAI", "API-адрес, совместимый с OpenAI"],
  "Stored securely in the macOS Keychain": ["安全存储在 macOS 钥匙串中", "安全地儲存在 macOS 鑰匙圈中", "macOS キーチェーンに安全に保存されます", "macOS 키체인에 안전하게 저장됨", "Se almacena de forma segura en el llavero de macOS", "Stockée en toute sécurité dans le trousseau macOS", "Sicher im macOS-Schlüsselbund gespeichert", "Armazenada com segurança nas Chaves do macOS", "Безопасно хранится в Связке ключей macOS"],
  "AI Assistance": ["AI 助手", "AI 助理", "AI アシスタント", "AI 지원", "Asistencia con IA", "Assistance IA", "KI-Unterstützung", "Assistência de IA", "Помощь ИИ"],
  "AI Features": ["AI 功能", "AI 功能", "AI 機能", "AI 기능", "Funciones de IA", "Fonctions d’IA", "KI-Funktionen", "Recursos de IA", "Функции ИИ"],
  "AI only provides explanations and recommendations. It never deletes files or ends processes automatically.": ["AI 只提供解释和建议，不会自动删除文件或结束进程。", "AI 僅提供說明和建議，不會自動刪除檔案或結束程序。", "AI は説明と提案のみを行い、ファイルの削除やプロセスの終了を自動では行いません。", "AI는 설명과 권장 사항만 제공하며 파일을 삭제하거나 프로세스를 자동으로 종료하지 않습니다.", "La IA solo ofrece explicaciones y recomendaciones. Nunca elimina archivos ni finaliza procesos automáticamente.", "L’IA fournit uniquement des explications et des recommandations. Elle ne supprime jamais de fichiers et ne termine aucun processus automatiquement.", "Die KI liefert nur Erklärungen und Empfehlungen. Sie löscht niemals automatisch Dateien und beendet keine Prozesse.", "A IA fornece apenas explicações e recomendações. Ela nunca exclui arquivos nem encerra processos automaticamente.", "ИИ предоставляет только объяснения и рекомендации. Он никогда не удаляет файлы и не завершает процессы автоматически."],
  "Enable AI explanations and personalized recommendations": ["启用 AI 解释和个性化建议", "啟用 AI 說明和個人化建議", "AI による説明とパーソナライズされた提案を有効にします", "AI 설명 및 맞춤형 권장 사항 활성화", "Activar explicaciones de IA y recomendaciones personalizadas", "Activer les explications de l’IA et les recommandations personnalisées", "KI-Erklärungen und personalisierte Empfehlungen aktivieren", "Ativar explicações de IA e recomendações personalizadas", "Включить объяснения ИИ и персональные рекомендации"],
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

// Removed setting: do not retain obsolete translations as manual entries.
delete catalog.strings["Allow paths, file types, sizes, and process details to be sent for analysis"];
delete catalog.strings["Share Technical Metadata"];
delete catalog.strings["Uninstall"];
delete catalog.strings["Storage Analysis"];
delete catalog.strings["Port Manager"];
delete catalog.strings["Login Items & Extensions"];
delete catalog.strings[""];
fs.writeFileSync(file, `${JSON.stringify(catalog, null, 2)}\n`);
