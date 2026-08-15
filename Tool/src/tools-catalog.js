const pageModules = import.meta.glob([
  "../tools/*/index.html",
  "!../tools/_*/index.html",
]);

const preferredOrder = [
  "hosts-manager",
  "timestamp-converter",
  "json-formatter",
  "codec",
  "string-generator",
];

/** Localized title/description for known tools; unknown folders still appear by id. */
export const toolMeta = {
  "hosts-manager": {
    title: {
      en: "Hosts Manager",
      "zh-Hans": "Hosts 管理",
      "zh-Hant": "Hosts 管理",
      ja: "Hosts 管理",
      ko: "Hosts 관리",
      es: "Gestor de hosts",
      fr: "Gestionnaire Hosts",
      de: "Hosts-Manager",
      "pt-BR": "Gerenciador de hosts",
      ru: "Менеджер hosts",
    },
    description: {
      en: "View the system hosts file and switch mappings between environments",
      "zh-Hans": "查看系统 hosts，并在开发环境间切换映射",
      "zh-Hant": "檢視系統 hosts，並在開發環境間切換對應",
      ja: "システム hosts を確認し、環境ごとにマッピングを切り替え",
      ko: "시스템 hosts를 확인하고 환경별 매핑을 전환",
      es: "Consulta /etc/hosts y cambia mapeos entre entornos",
      fr: "Consultez /etc/hosts et basculez les mappings par environnement",
      de: "System-Hosts ansehen und Umgebungs-Mappings wechseln",
      "pt-BR": "Veja o hosts do sistema e alterne mapeamentos entre ambientes",
      ru: "Просмотр /etc/hosts и переключение окружений",
    },
  },
  "timestamp-converter": {
    title: {
      en: "Timestamp Converter",
      "zh-Hans": "时间戳转换",
      "zh-Hant": "時間戳轉換",
      ja: "タイムスタンプ変換",
      ko: "타임스탬프 변환",
      es: "Conversor de marcas de tiempo",
      fr: "Convertisseur d’horodatage",
      de: "Zeitstempel-Konverter",
      "pt-BR": "Conversor de timestamp",
      ru: "Конвертер временных меток",
    },
    description: {
      en: "Convert dates and Unix timestamps across units and time zones",
      "zh-Hans": "在不同单位和时区之间转换日期与 Unix 时间戳",
      "zh-Hant": "在不同單位和時區之間轉換日期與 Unix 時間戳",
      ja: "日付と Unix タイムスタンプを単位・タイムゾーン間で変換",
      ko: "날짜와 Unix 타임스탬프를 단위 및 시간대별로 변환",
      es: "Convierte fechas y marcas Unix entre unidades y zonas",
      fr: "Convertissez dates et horodatages Unix entre unités et fuseaux",
      de: "Datum und Unix-Zeitstempel zwischen Einheiten und Zeitzonen",
      "pt-BR": "Converta datas e timestamps Unix entre unidades e fusos",
      ru: "Преобразование дат и меток Unix между единицами и поясами",
    },
  },
  "json-formatter": {
    title: {
      en: "JSON Formatter",
      "zh-Hans": "JSON 格式化",
      "zh-Hant": "JSON 格式化",
      ja: "JSON フォーマッタ",
      ko: "JSON 포맷터",
      es: "Formateador JSON",
      fr: "Formateur JSON",
      de: "JSON-Formatierer",
      "pt-BR": "Formatador JSON",
      ru: "Форматирование JSON",
    },
    description: {
      en: "Format, minify, and query JSON with path expressions",
      "zh-Hans": "格式化、压缩，并用路径表达式查询 JSON",
      "zh-Hant": "格式化、壓縮，並用路徑運算式查詢 JSON",
      ja: "JSON の整形・圧縮・パス式クエリ",
      ko: "JSON 포맷·압축 및 경로 표현식 조회",
      es: "Formatea, minifica y consulta JSON con rutas",
      fr: "Formatez, minifiez et interrogez du JSON par chemin",
      de: "JSON formatieren, verkleinern und per Pfad abfragen",
      "pt-BR": "Formate, minifique e consulte JSON com caminhos",
      ru: "Форматирование, сжатие и запросы JSON по путям",
    },
  },
  codec: {
    title: {
      en: "Codec",
      "zh-Hans": "编解码",
      "zh-Hant": "編解碼",
      ja: "コーデック",
      ko: "코덱",
      es: "Códec",
      fr: "Codec",
      de: "Codec",
      "pt-BR": "Codec",
      ru: "Кодек",
    },
    description: {
      en: "Encode and decode Base64, Hex, URL, HTML, Unicode, Escape, and Hash",
      "zh-Hans": "编解码 Base64、Hex、URL、HTML、Unicode、转义与哈希",
      "zh-Hant": "編解碼 Base64、Hex、URL、HTML、Unicode、跳脫與雜湊",
      ja: "Base64・Hex・URL・HTML・Unicode・エスケープ・ハッシュ",
      ko: "Base64, Hex, URL, HTML, Unicode, 이스케이프, 해시",
      es: "Codifica y decodifica Base64, Hex, URL, HTML, Unicode y hash",
      fr: "Encodez et décodez Base64, Hex, URL, HTML, Unicode et hash",
      de: "Kodieren und dekodieren: Base64, Hex, URL, HTML, Unicode, Hash",
      "pt-BR": "Codifique e decodifique Base64, Hex, URL, HTML, Unicode e hash",
      ru: "Кодирование Base64, Hex, URL, HTML, Unicode, escape и хеш",
    },
  },
  "string-generator": {
    title: {
      en: "String Generator",
      "zh-Hans": "字符串生成",
      "zh-Hant": "字串產生",
      ja: "文字列ジェネレーター",
      ko: "문자열 생성기",
      es: "Generador de cadenas",
      fr: "Générateur de chaînes",
      de: "String-Generator",
      "pt-BR": "Gerador de strings",
      ru: "Генератор строк",
    },
    description: {
      en: "Generate UUIDs, random IDs, and passwords locally",
      "zh-Hans": "本地生成 UUID、随机 ID 与密码",
      "zh-Hant": "本機產生 UUID、隨機 ID 與密碼",
      ja: "UUID・ランダム ID・パスワードをローカル生成",
      ko: "UUID, 임의 ID, 비밀번호를 로컬에서 생성",
      es: "Genera UUID, ID aleatorios y contraseñas en local",
      fr: "Générez UUID, ID aléatoires et mots de passe localement",
      de: "UUIDs, Zufalls-IDs und Passwörter lokal erzeugen",
      "pt-BR": "Gere UUIDs, IDs aleatórios e senhas localmente",
      ru: "Локально создавайте UUID, случайные ID и пароли",
    },
  },
};

export function discoverToolIds() {
  return Object.keys(pageModules)
    .map((path) => path.match(/\/tools\/([^/]+)\//)?.[1])
    .filter((id) => id && !id.startsWith("_"))
    .sort((left, right) => {
      const leftRank = preferredOrder.indexOf(left);
      const rightRank = preferredOrder.indexOf(right);
      if (leftRank === -1 && rightRank === -1) return left.localeCompare(right);
      if (leftRank === -1) return 1;
      if (rightRank === -1) return -1;
      return leftRank - rightRank;
    });
}

function pickLocale(map, locale) {
  if (!map) return "";
  return map[locale] || map.en || Object.values(map)[0] || "";
}

export function listTools(locale = "en") {
  return discoverToolIds().map((id) => {
    const meta = toolMeta[id];
    return {
      id,
      title: pickLocale(meta?.title, locale) || id,
      description: pickLocale(meta?.description, locale),
      href: `./tools/${id}/`,
    };
  });
}
