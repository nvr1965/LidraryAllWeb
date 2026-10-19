---
name: i18n-block
description: Наш общий блок многоязычности (React + PHP + PostgreSQL) — тексты интерфейса на любом языке с автопереводом (Gemini / Google / MyMemory), RTL для he/ar, выбор языка с флагами, админка языков, перевод заметок и данных на лету с кешем. Используй, когда в проекте нужно добавить язык, перевод интерфейса, i18n, локализацию, переключатель языка или RTL.
---

# i18n-block — общий блок перевода интерфейса

Эталон взят из проекта Hotels Maintenance (ветка feature/postgresql). Не изобретай i18n заново: перенеси файлы ниже в проект **по тем же путям** и адаптируй только то, что помечено в разделе «Что адаптировать».

## Как устроено
- `lang/en.json` — основа: все тексты интерфейса на английском, ключи вида `раздел.ключ` (`worker.title`, `admin.save`). Плейсхолдеры `{1}`, `{2}`. Входит в сборку фронтенда.
- Остальные языки — в таблице `ui_translations` (`is_auto = true` — переведено машиной, можно перевести заново; `false` — поправлено человеком, не трогать).
- Недостающие ключи сервер переводит сам после ответа клиенту (`ui_fill_language`, не чаще раза в 10 минут на язык, с advisory lock).
- Свободный текст (заметки, комментарии) — `translate_cached()`, кеш в `translation_cache` по sha256.
- Данные в jsonb вида `{"ru": "…", "en": "…"}` — `i18n_pick`, `i18n_complete`, `i18n_rows_on_the_fly`.
- Клиент: `uiText(ns, lang)` → словарь раздела; `loadUi(lang)` перед сменой языка; `useUi()` для перерисовки; `dirOf(lang)` → `rtl`/`ltr`; `localeOf(lang)` для дат и чисел. Тексты кешируются в localStorage с версией.

## Порядок подключения в новый проект
1. Выполнить `db/i18n_schema.sql`.
2. Скопировать backend/frontend файлы ниже.
3. Создать `lang/en.json` с текстами **этого** проекта (тексты Hotels Maintenance не переносить).
4. Ключи переводчика — в `backend/core/secrets.php` (не коммитить!):
   `<?php return ['gemini_api_key' => '...', 'google_translate_key' => '', 'translate_email' => ''];`
   Без ключей работает бесплатный MyMemory; `'translate_provider' => 'fake'` в config — для проверок без интернета.
5. `npm i flag-icons` (нужен `flags.js`, сборка — Vite из-за `import.meta.glob`).
6. Загрузить готовые переводы: `php tools/seed_ui.php` (`--fill` — допереводить недостающее). Папка `lang/seed/{ru,he,ar}.json` — переводы в формате `{ключ: текст}`.

## Что адаптировать под проект
- **Префикс localStorage** `STORE = 'hotelapp_ui_'` в `i18n.js` и имя метки `hotels_ui_fill_` в `ui_texts.php` — заменить на имя проекта.
- **Путь API** `/backend/api/ui_texts.php` в `i18n.js` — если структура другая.
- **`i18n_fill_hotel()`** в `translate.php` — специфична для отелей (список таблиц-справочников); переписать под таблицы проекта или удалить.
- **Проверка прав** в `admin_languages.php` (`app_current()`, `$me['is_superadmin']`) — под систему авторизации проекта.
- **Колонка «отели»** в админке: запрос к таблице `hotels` в `admin_languages.php` и столбец `t.hotels` в `AdminLanguages.jsx` — убрать или заменить своей сущностью.
- **Промпт Gemini** в `translate_gemini()` («hotel maintenance app…») — описать предметную область проекта: от этого зависит качество перевода.
- Префикс `hotels:` в `error_log` — на имя проекта.

## Зависимости, которых нет в блоке
Блок рассчитан на общее ядро проекта. Если его нет — создай эти функции:
- `backend/core/db.php` (PDO к PostgreSQL): `db_exec($sql, $params)` → PDOStatement, `db_all`, `db_one`, `db_value`, `db_tx(callable)`, `db_json($v)` (кодирует в json для jsonb).
- `backend/core/config.php`: `app_config()` → массив настроек; `app_languages()` → `[code => [code, name, native_name, is_rtl]]` из таблицы `languages` (активные, по `sort_order`); `app_normalize_lang($s)` → код из списка или `'en'`.
- `backend/core/api.php` (подключает db/config/ui_text): `api_ok($data)`, `api_fail($code)`, `app_json_fail($http, $code)`, `api_input()` → JSON тела запроса, `api_require_post()`, `app_current()` → текущий пользователь или null, `api_ok_then($data, callable)` — отправить ответ клиенту, закрыть соединение (`fastcgi_finish_request()`) и выполнить долгую работу после.
- В `admin_languages.php` ещё используются `clean_text($s, $maxLen)` (обрезать и почистить строку) и `audit($me, $action, $table, $id, $before, $after)` (журнал изменений; можно сделать пустой заглушкой).
- `AdminLanguages.jsx` импортирует из `./adminUi` общие вещи админки проекта: `tr(lang)` / `trNs(ns, lang)` (тексты, по сути `uiText`), `api(url, body?)` (fetch → JSON, POST если есть body), `errText(t, d)`, `S` (стили `th`, `td`, `badge(bg, color)`), `<Message msg>`, `<Ic n>` (иконки). Если `adminUi` в проекте нет — создай его или замени на свои.
- **Известная ошибка в эталоне:** в `AdminLanguages.jsx` вызывается `loadUi(lang)`, но не импортируется. При переносе добавь `import { loadUi } from '../../i18n';`.
- **`gemini_ocr.php` целиком не нужен** — это OCR счётчиков. `translate.php` берёт из него только `GeminiOCR::secret()`. Минимальная замена, `backend/core/gemini_ocr.php`:

```php
<?php
class GeminiOCR
{
    // Ключи — в backend/core/secrets.php (в git не входит)
    public static function secret(string $name): string
    {
        static $s = null;
        if ($s === null) {
            $f = __DIR__ . '/secrets.php';
            $s = is_file($f) ? require $f : [];
            if (!is_array($s)) $s = [];
        }
        return (string)($s[$name] ?? '');
    }
}
```

## Тексты экрана «Языки» для `lang/en.json`

Добавь эти ключи в `en.json` нового проекта (нужны `AdminLanguages.jsx`):

```json
{
    "langs.actions": "Actions",
    "langs.active": "Active",
    "langs.add": "➕ Add language",
    "langs.added": "Language added, interface is being translated",
    "langs.auto_n": "{1} machine-translated",
    "langs.base": "Base language",
    "langs.cancel": "Cancel",
    "langs.code": "Code (ISO)",
    "langs.empty": "Nothing found",
    "langs.fill": "Translate missing",
    "langs.fill_started": "Translation started",
    "langs.hotels": "Hotels",
    "langs.inactive": "Disabled",
    "langs.intro": "System languages and interface texts in them. A new language is available right away: the server translates all interface texts automatically. Any translation can be corrected by hand, and auto-translation will not touch it again.",
    "langs.language": "Language",
    "langs.loading": "Loading…",
    "langs.name_en": "Name in English",
    "langs.native": "Name in the language itself",
    "langs.only_auto": "Only machine-translated",
    "langs.order": "Order",
    "langs.placeholders": "The translation must keep the placeholders: {1}",
    "langs.progress": "Interface texts",
    "langs.provider": "Translation service",
    "langs.redo": "Re-translate auto",
    "langs.redo_confirm": "Re-translate all machine-translated texts? Texts corrected by hand will stay.",
    "langs.reset": "Return automatic translation",
    "langs.rtl": "Right to left",
    "langs.save": "Save",
    "langs.saved": "Saved",
    "langs.search": "Search by text or key",
    "langs.st_auto": "machine translation",
    "langs.st_manual": "corrected by hand",
    "langs.st_missing": "not translated yet",
    "langs.texts": "Texts",
    "langs.texts_hint": "Empty field and ↺ return the automatic translation. Keep placeholders like {1} and {app} as they are.",
    "langs.texts_of": "Interface texts: {1}",
    "langs.translating": "translating…"
}
```

## Код

### `db/i18n_schema.sql`

```sql

-- ---------------------------------------------------------------- языки

CREATE TABLE IF NOT EXISTS languages (
    code        text PRIMARY KEY CHECK (code ~ '^[a-z]{2,3}(-[A-Za-z]{2,4})?$'),
    name        text NOT NULL,                       -- по-английски: Russian
    native_name text,                                -- на самом языке: Русский
    is_rtl      boolean NOT NULL DEFAULT false,
    is_active   boolean NOT NULL DEFAULT true,
    sort_order  integer NOT NULL DEFAULT 100
);
COMMENT ON TABLE languages IS 'Языки системы. Английский — основа интерфейса, его не удаляют';

INSERT INTO languages (code, name, native_name, is_rtl, sort_order) VALUES
    ('en', 'English', 'English', false, 10),
    ('ru', 'Russian', 'Русский', false, 20),
    ('he', 'Hebrew', 'עברית', true, 30),
    ('ar', 'Arabic', 'العربية', true, 40)
ON CONFLICT (code) DO NOTHING;

-- Тексты интерфейса. Английские лежат в коде (lang/en.json), здесь — остальные языки.
-- is_auto: переведено автоматически (такие можно перевести заново), false — поправлено человеком.
CREATE TABLE IF NOT EXISTS ui_translations (
    key           text NOT NULL,
    language_code text NOT NULL REFERENCES languages(code) ON UPDATE CASCADE ON DELETE CASCADE,
    text          text NOT NULL,
    is_auto       boolean NOT NULL DEFAULT true,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (key, language_code)
);

-- Кеш перевода на лету (заметки, комментарии, любой свободный текст): один раз перевели — дальше из кеша
CREATE TABLE IF NOT EXISTS translation_cache (
    src_hash   char(64) NOT NULL,                    -- sha256 исходного текста
    from_lang  text NOT NULL,
    to_lang    text NOT NULL,
    text       text NOT NULL,
    provider   text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (src_hash, from_lang, to_lang)
);
```

### `backend/core/ui_text.php`

```php
<?php
/* Тексты интерфейса на сервере (уведомления, письма, страницы без React).
 * Английские — основа, в lang/en.json (общий файл с интерфейсом); остальные языки — в таблице
 * ui_translations, их заполняет автоперевод при добавлении языка (страница «Языки»).
 */
require_once __DIR__ . '/db.php';

function ui_base(): array
{
    static $en = null;
    if ($en === null) {
        $en = json_decode((string)@file_get_contents(__DIR__ . '/../../lang/en.json'), true);
        if (!is_array($en)) $en = [];
    }
    return $en;
}

/** Текст по ключу на языке $lang (чего нет — по-английски). %s подставляются из $args. */
function ui_t(string $key, string $lang, ...$args): string
{
    static $cache = [];
    if (!isset($cache[$lang])) {
        $cache[$lang] = $lang === 'en' ? [] : db_exec("SELECT key, text FROM ui_translations WHERE language_code = ?", [$lang])
            ->fetchAll(PDO::FETCH_KEY_PAIR);
    }
    $text = $cache[$lang][$key] ?? ui_base()[$key] ?? $key;
    return $args ? vsprintf($text, $args) : $text;
}

/** Пишется ли язык справа налево (по таблице languages). */
function ui_is_rtl(string $lang): bool
{
    return (bool)(app_languages()[$lang]['is_rtl'] ?? false);
}

/**
 * Словарь текстов из кода (выгрузки, страницы без React) на язык $lang: готовый, если он есть в $byLang,
 * иначе английский в автопереводе (через кеш переводов). Значения — строки или списки строк.
 */
function ui_dict(array $byLang, string $lang): array
{
    if (isset($byLang[$lang])) return $byLang[$lang];
    require_once __DIR__ . '/translate.php';
    $en = $byLang['en'];
    $flat = [];
    foreach ($en as $k => $v) {
        if (is_array($v)) foreach ($v as $i => $x) $flat["$k\t$i"] = $x;
        else $flat[$k] = $v;
    }
    $tr = translate_cached_many($flat, 'en', $lang);
    foreach ($en as $k => $v) {
        if (is_array($v)) foreach ($v as $i => $x) $en[$k][$i] = $tr["$k\t$i"];
        else $en[$k] = $tr[$k];
    }
    return $en;
}

/** Метки подстановки в тексте: {1}, {app}, %s — перевод без них (или с лишними) не годится. */
function ui_placeholders(string $s): array
{
    preg_match_all('/\{[a-z0-9_]+\}|%[sd]/i', $s, $m);
    $p = $m[0];
    sort($p);
    return $p;
}

/**
 * Перевести тексты интерфейса на язык $lang: недостающие ключи, а с $redoAuto — и переведённые автоматически
 * раньше (поправленные людьми не трогаются). Пачками по 50, ошибки сервиса — в журнал. Возвращает число записанных.
 */
function ui_fill_language(string $lang, bool $redoAuto = false): int
{
    if ($lang === 'en') return 0;
    require_once __DIR__ . '/translate.php';
    set_time_limit(900);
    $base = ui_base();
    $have = db_exec("SELECT key, is_auto FROM ui_translations WHERE language_code = ?", [$lang])->fetchAll(PDO::FETCH_KEY_PAIR);
    $todo = [];
    foreach ($base as $key => $en) {
        if (!array_key_exists($key, $have) || ($redoAuto && $have[$key])) $todo[$key] = $en;
    }
    $n = 0;
    foreach (array_chunk($todo, 50, true) as $chunk) {
        try {
            $done = translate_texts($chunk, 'en', $lang);
        } catch (Throwable $e) {
            error_log("hotels: ui translate en→{$lang}: " . $e->getMessage());
            continue;
        }
        foreach ($done as $key => $text) {
            $text = trim((string)$text);
            // Перевод сломал метки ({1}, {app}) — записываем английский как «автоматический», чтобы не переводить
            // его заново при каждом открытии; «Перевести заново» на странице «Языки» попробует ещё раз
            if ($text === '' || ui_placeholders($text) !== ui_placeholders($chunk[$key])) $text = $chunk[$key];
            db_exec("INSERT INTO ui_translations (key, language_code, text, is_auto) VALUES (?, ?, ?, true)
                     ON CONFLICT (key, language_code) DO UPDATE SET text = EXCLUDED.text, is_auto = true, updated_at = now()
                     WHERE ui_translations.is_auto", [$key, $lang, $text]);
            $n++;
        }
    }
    return $n;
}

/** Сколько ключей интерфейса ещё без перевода на $lang. */
function ui_missing_count(string $lang): int
{
    if ($lang === 'en') return 0;
    $have = db_exec("SELECT key FROM ui_translations WHERE language_code = ?", [$lang])->fetchAll(PDO::FETCH_COLUMN);
    return count(array_diff(array_keys(ui_base()), $have));
}
```

### `backend/core/translate.php`

```php
<?php
/* Машинный перевод и тексты на языках.
 *
 * Сервисы (выбирается сам, или 'translate_provider' в config.local.php):
 *   google   — Google Cloud Translation, если в secrets.php есть google_translate_key;
 *   gemini   — Gemini, если есть gemini_api_key (тот же ключ, что для счётчиков);
 *   mymemory — бесплатный MyMemory без ключа (5 000 знаков в день, с 'translate_email' 50 000);
 *   fake     — без интернета, «[xx] текст»: только для проверок на своём компьютере.
 * Механизм тот же, что в Allservice (app/admin/translate.php), плюс Gemini.
 *
 * Тексты на языках хранятся как jsonb {"ru": "…", "en": "…"}:
 *   i18n_pick($map, $lang)                       — текст на языке, иначе на английском, иначе любой;
 *   i18n_complete($map, $langs, $src)            — дописать недостающие языки переводом;
 *   i18n_rows_on_the_fly($table, $rows, $col, …) — перевод на лету с записью в ту же строку;
 *   i18n_fill_hotel($hotelId, $langs)            — дописать языки во все справочники отеля.
 * Свободный текст без jsonb (заметки) — translate_cached(): кеш в translation_cache.
 */
require_once __DIR__ . '/gemini_ocr.php';

const TR_GOOGLE_URL = 'https://translation.googleapis.com/language/translate/v2';
const TR_GOOGLE_BATCH = 100;
const TR_MYMEMORY_URL = 'https://api.mymemory.translated.net/get';
const TR_MYMEMORY_PARALLEL = 8;
const TR_MYMEMORY_MAX_BYTES = 450;
const TR_GEMINI_MODEL = 'gemini-flash-lite-latest';

function translate_provider(): string
{
    $want = (string)(app_config()['translate_provider'] ?? 'auto');
    if ($want !== 'auto') return $want;
    if (GeminiOCR::secret('google_translate_key') !== '') return 'google';
    if (GeminiOCR::secret('gemini_api_key') !== '') return 'gemini';
    return 'mymemory';
}

/**
 * Переводит тексты, сохраняя ключи. $from = '' — язык определить самим.
 * @throws RuntimeException с ошибкой сервиса
 */
function translate_texts(array $texts, string $from, string $to): array
{
    $texts = array_filter($texts, fn($t) => trim((string)$t) !== '');
    if (!$texts || $from === $to) return $texts;
    switch (translate_provider()) {
        case 'google': return translate_google($texts, $from, $to);
        case 'gemini': return translate_gemini($texts, $from, $to);
        case 'fake':   return array_map(fn($t) => "[$to] $t", $texts);
        default:       return translate_mymemory_split($texts, $from, $to);
    }
}

function translate_lang_name(string $code): string
{
    $l = app_languages()[$code] ?? null;
    return $l ? "{$l['name']} ($code)" : $code;
}

function translate_gemini(array $texts, string $from, string $to): array
{
    $keys = array_keys($texts);
    $prompt = "You translate short texts for a hotel maintenance app (rooms, repairs, equipment, meters). "
        . "Translate each item of the JSON array " . ($from !== '' ? 'from ' . translate_lang_name($from) . ' ' : '')
        . "into " . translate_lang_name($to) . ". Keep numbers, room numbers, placeholders like {1}, {app}, %s and emoji exactly as they are. "
        . "Answer with a JSON array of strings only, same length and order.\n\n"
        . json_encode(array_values($texts), JSON_UNESCAPED_UNICODE);
    $body = json_encode([
        'contents' => [['role' => 'user', 'parts' => [['text' => $prompt]]]],
        'generationConfig' => ['temperature' => 0.1, 'responseMimeType' => 'application/json'],
    ], JSON_UNESCAPED_UNICODE);
    $ch = curl_init('https://generativelanguage.googleapis.com/v1beta/models/' . TR_GEMINI_MODEL . ':generateContent');
    curl_setopt_array($ch, [
        CURLOPT_POST => true, CURLOPT_POSTFIELDS => $body, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 40,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'x-goog-api-key: ' . GeminiOCR::secret('gemini_api_key')],
    ]);
    $res = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    $data = is_string($res) ? json_decode($res, true) : null;
    $raw = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
    $arr = is_string($raw) ? json_decode($raw, true) : null;
    if ($code !== 200 || !is_array($arr) || count($arr) !== count($keys)) {
        throw new RuntimeException('Gemini: ' . ($data['error']['message'] ?? ($err ?: "HTTP $code")));
    }
    $out = [];
    foreach ($keys as $i => $k) $out[$k] = trim((string)$arr[$i]);
    return $out;
}

function translate_google(array $texts, string $from, string $to): array
{
    $out = [];
    foreach (array_chunk($texts, TR_GOOGLE_BATCH, true) as $chunk) {
        $body = http_build_query(['target' => $to, 'format' => 'text'] + ($from !== '' ? ['source' => $from] : []));
        foreach ($chunk as $text) $body .= '&q=' . rawurlencode($text);
        $ch = curl_init(TR_GOOGLE_URL . '?key=' . rawurlencode(GeminiOCR::secret('google_translate_key')));
        curl_setopt_array($ch, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => $body, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 30]);
        $res = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        curl_close($ch);
        $data = is_string($res) ? json_decode($res, true) : null;
        if ($code !== 200 || !isset($data['data']['translations'])) {
            throw new RuntimeException('Google: ' . ($data['error']['message'] ?? ($err ?: "HTTP $code")));
        }
        foreach (array_keys($chunk) as $i => $k) {
            $out[$k] = trim(html_entity_decode($data['data']['translations'][$i]['translatedText'] ?? '', ENT_QUOTES | ENT_HTML5, 'UTF-8'));
        }
    }
    return $out;
}

// MyMemory берёт не больше 500 байт за раз: длинные тексты переводятся по кускам и склеиваются
function translate_mymemory_split(array $texts, string $from, string $to): array
{
    $pieces = [];
    foreach ($texts as $k => $text) {
        foreach (translate_split($text, TR_MYMEMORY_MAX_BYTES) as $i => $piece) $pieces["$k\x1f$i"] = $piece;
    }
    $out = array_fill_keys(array_keys($texts), '');
    foreach (translate_mymemory($pieces, $from, $to) as $key => $done) {
        [$k, $i] = explode("\x1f", (string)$key);
        $k = array_key_exists($k, $out) ? $k : (int)$k;
        $out[$k] .= ($i === '0' ? '' : ($pieces[$key][0] === "\n" ? "\n" : ' ')) . $done;
    }
    return $out;
}

function translate_split(string $text, int $max): array
{
    if (strlen($text) <= $max) return [$text];
    $parts = [];
    foreach (preg_split('/\R+/u', $text) as $p => $para) {
        $lead = $p > 0 ? "\n" : '';
        $buf = '';
        foreach (preg_split('/\s+/u', $para, -1, PREG_SPLIT_NO_EMPTY) as $word) {
            if ($buf !== '' && strlen($buf) + 1 + strlen($word) > $max) {
                $parts[] = $lead . $buf;
                $lead = '';
                $buf = '';
            }
            $buf = $buf === '' ? mb_strcut($word, 0, $max) : "$buf $word";
        }
        if ($buf !== '') $parts[] = $lead . $buf;
    }
    return $parts;
}

function translate_mymemory(array $texts, string $from, string $to): array
{
    $email = (string)(app_config()['translate_email'] ?? '');
    @set_time_limit(300);
    $out = [];
    foreach (array_chunk($texts, TR_MYMEMORY_PARALLEL, true) as $chunk) {
        $mh = curl_multi_init();
        $handles = [];
        foreach ($chunk as $k => $text) {
            $query = ['q' => $text, 'langpair' => ($from !== '' ? $from : 'autodetect') . "|$to"] + ($email !== '' ? ['de' => $email] : []);
            $ch = curl_init(TR_MYMEMORY_URL . '?' . http_build_query($query));
            curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 30]);
            curl_multi_add_handle($mh, $ch);
            $handles[$k] = $ch;
        }
        do {
            $status = curl_multi_exec($mh, $running);
            if ($running) curl_multi_select($mh);
        } while ($running && $status === CURLM_OK);
        $error = '';
        foreach ($handles as $k => $ch) {
            $data = json_decode((string)curl_multi_getcontent($ch), true);
            $text = $data['responseData']['translatedText'] ?? '';
            $code = (int)($data['responseStatus'] ?? curl_getinfo($ch, CURLINFO_HTTP_CODE));
            if ($code !== 200 || $text === '' || str_starts_with($text, 'MYMEMORY WARNING')) {
                $error = $data['responseDetails'] ?? ($text ?: (curl_error($ch) ?: "HTTP $code"));
            }
            $out[$k] = trim(html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
        }
        curl_multi_close($mh);
        if ($error !== '') throw new RuntimeException('MyMemory: ' . $error);
    }
    return $out;
}

// ---------------------------------------------------------------- тексты на языках (jsonb)

/** Текст на языке $lang: иначе на английском, иначе первый непустой. */
function i18n_pick($map, string $lang): string
{
    $m = db_json($map);
    foreach ([$lang, 'en'] as $l) if (isset($m[$l]) && trim((string)$m[$l]) !== '') return (string)$m[$l];
    foreach ($m as $v) if (is_string($v) && trim($v) !== '') return $v;
    return '';
}

/** Исходный язык карты: заданный, иначе английский, иначе первый непустой. */
function i18n_source(array $m, ?string $src = null): ?string
{
    if ($src && trim((string)($m[$src] ?? '')) !== '') return $src;
    if (trim((string)($m['en'] ?? '')) !== '') return 'en';
    foreach ($m as $l => $v) if (is_string($v) && trim($v) !== '') return (string)$l;
    return null;
}

/**
 * Дописывает в карту недостающие языки из $langs переводом с исходного.
 * Если перевод не удался, язык остаётся пустым (покажется исходный текст) — сохранение не ломается.
 */
function i18n_complete(array $m, array $langs, ?string $src = null): array
{
    $m = array_filter(array_map(fn($v) => trim((string)$v), $m), fn($v) => $v !== '');
    $from = i18n_source($m, $src);
    if ($from === null) return $m;
    foreach ($langs as $l) {
        if ($l === $from || isset($m[$l])) continue;
        try {
            $t = translate_texts(['x' => $m[$from]], $from, $l)['x'] ?? '';
            if ($t !== '') $m[$l] = $t;
        } catch (Throwable $e) {
            error_log("hotels: translate {$from}→{$l}: " . $e->getMessage());
        }
    }
    return $m;
}

/** Справочники отеля (jsonb names), в которых заполняются недостающие языки. */
const I18N_HOTEL_DICTS = ['asset_dictionary', 'room_checklist_dict', 'routine_tasks', 'hotel_departments'];

/**
 * Дописать во все справочники отеля недостающие языки из $langs (автоперевод пачками: один вызов
 * сервиса на пару языков и таблицу). Нужен после копирования справочников и при добавлении языка.
 * Возвращает число дописанных переводов; ошибки сервиса пишутся в журнал, остальное продолжается.
 */
function i18n_fill_hotel(int $hotelId, array $langs): int
{
    set_time_limit(600);
    $n = 0;
    foreach (I18N_HOTEL_DICTS as $table) {
        $todo = [];
        foreach (db_all("SELECT id, names FROM $table WHERE hotel_id = ?", [$hotelId]) as $r) {
            $m = db_json($r['names']);
            $src = i18n_source($m);
            if ($src === null) continue;
            foreach ($langs as $l) {
                if ($l !== $src && trim((string)($m[$l] ?? '')) === '') $todo["$src>$l"][(int)$r['id']] = $m[$src];
            }
        }
        foreach ($todo as $pair => $texts) {
            [$from, $to] = explode('>', $pair);
            foreach (array_chunk($texts, 50, true) as $chunk) {
                try {
                    $done = translate_texts($chunk, $from, $to);
                } catch (Throwable $e) {
                    error_log("hotels: translate {$from}→{$to} ($table): " . $e->getMessage());
                    continue;
                }
                foreach ($done as $id => $t) {
                    if ($t === '') continue;
                    db_exec("UPDATE $table SET names = names || jsonb_build_object(?::text, ?::text) WHERE id = ?", [$to, $t, $id]);
                    $n++;
                }
            }
        }
    }
    return $n;
}

/** Свободный текст на язык $to через кеш. $from = '' — определить. При ошибке — исходный текст. */
function translate_cached(string $text, string $from, string $to): string
{
    $text = trim($text);
    if ($text === '' || $from === $to) return $text;
    $hash = hash('sha256', $text);
    $hit = db_value("SELECT text FROM translation_cache WHERE src_hash = ? AND from_lang = ? AND to_lang = ?", [$hash, $from, $to]);
    if ($hit !== null) return (string)$hit;
    try {
        $t = translate_texts(['x' => $text], $from, $to)['x'] ?? '';
    } catch (Throwable $e) {
        error_log("hotels: translate {$from}→{$to}: " . $e->getMessage());
        return $text;
    }
    if ($t === '') return $text;
    db_exec("INSERT INTO translation_cache (src_hash, from_lang, to_lang, text, provider) VALUES (?, ?, ?, ?, ?)
             ON CONFLICT DO NOTHING", [$hash, $from, $to, $t, translate_provider()]);
    return $t;
}

/** Пачка текстов на язык $to через кеш (ключи сохраняются); недостающее — одним вызовом сервиса. При ошибке — исходные. */
function translate_cached_many(array $texts, string $from, string $to): array
{
    if ($from === $to || !$texts) return $texts;
    $hashes = array_map(fn($t) => hash('sha256', trim((string)$t)), $texts);
    $hit = db_exec("SELECT src_hash, text FROM translation_cache WHERE from_lang = ? AND to_lang = ? AND src_hash = ANY(?::char(64)[])",
        [$from, $to, '{' . implode(',', array_unique($hashes)) . '}'])->fetchAll(PDO::FETCH_KEY_PAIR);
    $miss = [];
    foreach ($texts as $k => $t) if (trim((string)$t) !== '' && !isset($hit[$hashes[$k]])) $miss[$hashes[$k]] = trim((string)$t);
    if ($miss) {
        try {
            foreach (translate_texts($miss, $from, $to) as $h => $t) {
                if ($t === '') continue;
                $hit[$h] = $t;
                db_exec("INSERT INTO translation_cache (src_hash, from_lang, to_lang, text, provider) VALUES (?, ?, ?, ?, ?)
                         ON CONFLICT DO NOTHING", [$h, $from, $to, $t, translate_provider()]);
            }
        } catch (Throwable $e) {
            error_log("hotels: translate {$from}→{$to}: " . $e->getMessage());
        }
    }
    $out = [];
    foreach ($texts as $k => $t) $out[$k] = $hit[$hashes[$k]] ?? $t;
    return $out;
}

/**
 * Перевод на лету для строк с jsonb-колонкой: тем, у кого нет нужного языка, он дописывается
 * переводом с языка автора ($col . '_lang') и сохраняется, второй раз сервис не вызывается.
 * $rows — строки с 'id' и $col (jsonb-текст). Возвращает строки, где $col уже текст на $lang,
 * а $col . '_orig' — оригинал (если язык другой).
 */
function i18n_rows_on_the_fly(string $table, array $rows, string $col, string $lang): array
{
    if (!preg_match('/^[a-z_]+$/', $table . $col)) throw new InvalidArgumentException('bad identifier');
    // Недостающие переводы собираем по исходному языку и переводим пачкой: один вызов сервиса на язык автора
    $maps = $todo = [];
    foreach ($rows as $i => $r) {
        $m = db_json($r[$col] ?? null);
        $src = i18n_source($m, $r[$col . '_lang'] ?? null);
        $maps[$i] = [$m, $src];
        if ($src !== null && $src !== $lang && trim((string)($m[$lang] ?? '')) === '') $todo[$src][$i] = $m[$src];
    }
    foreach ($todo as $src => $texts) {
        try {
            $done = translate_texts($texts, $src, $lang);
        } catch (Throwable $e) {
            error_log("hotels: translate {$src}→{$lang}: " . $e->getMessage());
            continue;
        }
        foreach ($done as $i => $t) {
            if ($t === '') continue;
            $maps[$i][0][$lang] = $t;
            // Язык автора, если не был записан, фиксируем: иначе исходным стал бы английский перевод
            db_exec("UPDATE $table SET $col = $col || jsonb_build_object(?::text, ?::text), {$col}_lang = COALESCE({$col}_lang, ?)
                     WHERE id = ?", [$lang, $t, $src, $rows[$i]['id']]);
        }
    }
    foreach ($rows as $i => &$r) {
        [$m, $src] = $maps[$i];
        $r[$col] = i18n_pick($m, $lang);
        // Оригинал — только если показан перевод (не удалось перевести — показан сам оригинал)
        $r[$col . '_orig'] = $src !== null && $src !== $lang && trim((string)($m[$lang] ?? '')) !== '' ? (string)($m[$src] ?? '') : null;
    }
    unset($r);
    return $rows;
}

/**
 * Свободный текст в строках ($col, язык автора в $langCol) на язык $lang: из кеша, недостающее — одной пачкой.
 * В строке остаётся перевод, оригинал — в $col . '_orig' (если язык другой). Без языка автора текст не трогаем.
 */
function i18n_free_rows(array $rows, string $col, string $langCol, string $lang): array
{
    $todo = [];
    foreach ($rows as $i => $r) {
        $text = trim((string)($r[$col] ?? ''));
        $src = (string)($r[$langCol] ?? '');
        if ($text !== '' && $src !== '' && $src !== $lang) $todo[$src][$i] = $text;
    }
    foreach ($todo as $src => $texts) {
        $hashes = array_map(fn($t) => hash('sha256', $t), $texts);
        $hit = $hashes ? db_exec("SELECT src_hash, text FROM translation_cache WHERE from_lang = ? AND to_lang = ? AND src_hash = ANY(?::char(64)[])",
            [$src, $lang, '{' . implode(',', array_unique($hashes)) . '}'])->fetchAll(PDO::FETCH_KEY_PAIR) : [];
        $miss = array_filter($texts, fn($t, $i) => !isset($hit[$hashes[$i]]), ARRAY_FILTER_USE_BOTH);
        if ($miss) {
            try {
                foreach (translate_texts(array_unique($miss), $src, $lang) as $i => $t) {
                    if ($t === '') continue;
                    $hit[$hashes[$i]] = $t;
                    db_exec("INSERT INTO translation_cache (src_hash, from_lang, to_lang, text, provider) VALUES (?, ?, ?, ?, ?)
                             ON CONFLICT DO NOTHING", [$hashes[$i], $src, $lang, $t, translate_provider()]);
                }
            } catch (Throwable $e) {
                error_log("hotels: translate {$src}→{$lang}: " . $e->getMessage());
            }
        }
        foreach ($texts as $i => $t) {
            if (!isset($hit[$hashes[$i]])) continue;
            $rows[$i][$col . '_orig'] = $t;
            $rows[$i][$col] = $hit[$hashes[$i]];
        }
    }
    return $rows;
}
```

### `backend/api/ui_texts.php`

```php
<?php
/* Тексты интерфейса на языке (без входа: нужны и экрану входа). GET ?lang=xx[&have=версия]
 * → {languages: [{code, name, rtl}], lang, version, texts: {ключ: текст} | null (если версия та же)}
 * Английские тексты фронтенд берёт из своей сборки (lang/en.json), здесь — переводы.
 * Если каких-то ключей на этом языке ещё нет, они переводятся автоматически сразу после ответа
 * (при следующем открытии уже придут переведёнными).
 */
require_once __DIR__ . '/../core/api.php';

$languages = array_values(array_map(fn($l) => ['code' => $l['code'], 'name' => $l['native_name'] ?: $l['name'], 'rtl' => (bool)$l['is_rtl']],
    app_languages()));
$lang = app_normalize_lang($_GET['lang'] ?? 'en');

$texts = [];
$version = 'en';
if ($lang !== 'en') {
    $texts = db_exec("SELECT key, text FROM ui_translations WHERE language_code = ?", [$lang])->fetchAll(PDO::FETCH_KEY_PAIR);
    $version = substr(hash('sha256', json_encode($texts, JSON_UNESCAPED_UNICODE)), 0, 16);
}
$out = [
    'languages' => $languages,
    'lang' => $lang,
    'version' => $version,
    'texts' => ($_GET['have'] ?? '') === $version ? null : (object)$texts,
];

// Не чаще раза в 10 минут на язык: если сервис перевода недоступен, не дёргаем его на каждом открытии
$mark = sys_get_temp_dir() . '/hotels_ui_fill_' . preg_replace('/[^a-zA-Z-]/', '', $lang);
if ($lang !== 'en' && count($texts) < count(ui_base()) && (!is_file($mark) || filemtime($mark) < time() - 600)) {
    @touch($mark);
    // Переводит только один процесс на язык; остальные просто отвечают тем, что есть
    api_ok_then($out + ['filling' => true], function () use ($lang) {
        if (!db_value("SELECT pg_try_advisory_lock(hashtext(?))", ['ui_fill:' . $lang])) return;
        try {
            ui_fill_language($lang);
        } finally {
            db_exec("SELECT pg_advisory_unlock(hashtext(?))", ['ui_fill:' . $lang]);
        }
    });
}
api_ok($out);
```

### `backend/api/admin_languages.php`

```php
<?php
/* Админка → Языки (только владелец системы): языки системы и тексты интерфейса на них.
 * Новый язык сразу доступен; все тексты интерфейса переводятся автоматически сразу после ответа,
 * любой перевод можно поправить руками (такой текст автоперевод больше не трогает).
 *
 * GET  ?action=list                         — языки: сколько текстов переведено, сколько автоматически, в скольких отелях
 * POST ?action=save   {code, name, native_name?, rtl?, active?, sort_order?}   — новый язык или правка
 * POST ?action=fill   {code, redo?}         — перевести недостающее (redo — и автоматические заново)
 * GET  ?action=texts&code=xx&q=             — тексты: ключ, английский, перевод, автоматический ли
 * POST ?action=text   {code, key, text}     — поправить перевод (пусто — вернуть автоперевод)
 */
require_once __DIR__ . '/../core/api.php';

$me = app_current();
if (!$me) app_json_fail(401, 'auth_required');
if ($me['is_superadmin'] !== 1) app_json_fail(403, 'forbidden');
$action = $_GET['action'] ?? 'list';
if (!in_array($action, ['list', 'texts'], true)) api_require_post();
$in = api_input();

const LANG_CODE_RE = '/^[a-z]{2,3}(-[A-Za-z]{2,4})?$/';

function lang_row(string $code): ?array
{
    return db_one("SELECT * FROM languages WHERE code = ?", [$code]);
}

/** Перевести интерфейс на язык после ответа; один процесс на язык. */
function lang_fill_after(array $data, string $code, bool $redo): void
{
    api_ok_then($data, function () use ($code, $redo) {
        if (!db_value("SELECT pg_try_advisory_lock(hashtext(?))", ['ui_fill:' . $code])) return;
        try {
            ui_fill_language($code, $redo);
        } finally {
            db_exec("SELECT pg_advisory_unlock(hashtext(?))", ['ui_fill:' . $code]);
        }
    });
}

/** Идёт ли сейчас автоперевод языка (замок занят другим процессом). */
function lang_filling(string $code): bool
{
    if (db_value("SELECT pg_try_advisory_lock(hashtext(?))", ['ui_fill:' . $code])) {
        db_exec("SELECT pg_advisory_unlock(hashtext(?))", ['ui_fill:' . $code]);
        return false;
    }
    return true;
}

if ($action === 'list') {
    $total = count(ui_base());
    $stats = [];
    foreach (db_all("SELECT language_code, COUNT(*) AS n, COUNT(*) FILTER (WHERE is_auto) AS auto
                     FROM ui_translations GROUP BY language_code") as $r) $stats[$r['language_code']] = $r;
    $hotels = db_exec("SELECT l, COUNT(*) FROM hotels, unnest(languages) AS l GROUP BY l")->fetchAll(PDO::FETCH_KEY_PAIR);
    $out = [];
    foreach (db_all("SELECT * FROM languages ORDER BY sort_order, code") as $l) {
        $c = $l['code'];
        $out[] = [
            'code' => $c, 'name' => $l['name'], 'native_name' => $l['native_name'], 'rtl' => (bool)$l['is_rtl'],
            'active' => (bool)$l['is_active'], 'sort_order' => (int)$l['sort_order'],
            'translated' => $c === 'en' ? $total : min($total, (int)($stats[$c]['n'] ?? 0)),
            'auto' => (int)($stats[$c]['auto'] ?? 0),
            'hotels' => (int)($hotels[$c] ?? 0),
            'filling' => $c !== 'en' && lang_filling($c),
        ];
    }
    api_ok(['languages' => $out, 'total' => $total, 'provider' => translate_provider()]);
}

if ($action === 'save') {
    $code = trim((string)($in['code'] ?? ''));
    if (!preg_match(LANG_CODE_RE, $code)) api_fail('bad_code');
    $name = clean_text($in['name'] ?? '', 60);
    if ($name === '') api_fail('name_required');
    $before = lang_row($code);
    $data = [
        'name' => $name,
        'native_name' => clean_text($in['native_name'] ?? ($before['native_name'] ?? ''), 60) ?: null,
        'is_rtl' => array_key_exists('rtl', $in) ? !empty($in['rtl']) : (bool)($before['is_rtl'] ?? false),
        'is_active' => array_key_exists('active', $in) ? !empty($in['active']) : (bool)($before['is_active'] ?? true),
        'sort_order' => isset($in['sort_order']) ? (int)$in['sort_order'] : (int)($before['sort_order'] ?? 100),
    ];
    if ($code === 'en' && !$data['is_active']) api_fail('base_language'); // английский — основа интерфейса
    if ($before) {
        db_exec("UPDATE languages SET name = ?, native_name = ?, is_rtl = ?, is_active = ?, sort_order = ? WHERE code = ?",
            array_merge(array_values($data), [$code]));
        audit($me, 'update', 'languages', $code, $before, lang_row($code));
        api_ok(['code' => $code]);
    }
    db_exec("INSERT INTO languages (code, name, native_name, is_rtl, is_active, sort_order) VALUES (?, ?, ?, ?, ?, ?)",
        array_merge([$code], array_values($data)));
    audit($me, 'insert', 'languages', $code, null, lang_row($code));
    // Новый язык: интерфейс переводится сразу, страница «Языки» покажет, сколько готово
    lang_fill_after(['code' => $code, 'filling' => true], $code, false);
}

if ($action === 'fill') {
    $code = (string)($in['code'] ?? '');
    if (!lang_row($code)) api_fail('not_found');
    if ($code === 'en') api_fail('base_language');
    lang_fill_after(['code' => $code, 'filling' => true], $code, !empty($in['redo']));
}

if ($action === 'texts') {
    $code = (string)($_GET['code'] ?? '');
    if (!lang_row($code)) api_fail('not_found');
    $q = mb_strtolower(trim((string)($_GET['q'] ?? '')));
    $tr = [];
    foreach (db_all("SELECT key, text, is_auto FROM ui_translations WHERE language_code = ?", [$code]) as $r) $tr[$r['key']] = $r;
    $rows = [];
    foreach (ui_base() as $key => $en) {
        $t = $tr[$key] ?? null;
        if ($q !== '' && !str_contains(mb_strtolower($key . ' ' . $en . ' ' . ($t['text'] ?? '')), $q)) continue;
        $rows[] = ['key' => $key, 'en' => $en, 'text' => $t['text'] ?? null, 'auto' => $t ? (bool)$t['is_auto'] : null];
    }
    api_ok(['code' => $code, 'rows' => $rows]);
}

if ($action === 'text') {
    $code = (string)($in['code'] ?? '');
    $key = (string)($in['key'] ?? '');
    if ($code === 'en' || !lang_row($code)) api_fail('not_found');
    if (!array_key_exists($key, ui_base())) api_fail('bad_key');
    $text = trim((string)($in['text'] ?? ''));
    $before = db_one("SELECT * FROM ui_translations WHERE key = ? AND language_code = ?", [$key, $code]);
    if ($text === '') {
        // Пусто — убрать ручной перевод: ключ переведётся автоматически при следующем открытии на этом языке
        db_exec("DELETE FROM ui_translations WHERE key = ? AND language_code = ?", [$key, $code]);
    } else {
        if (ui_placeholders($text) !== ui_placeholders(ui_base()[$key])) api_fail('placeholders', ['need' => ui_placeholders(ui_base()[$key])]);
        db_exec("INSERT INTO ui_translations (key, language_code, text, is_auto) VALUES (?, ?, ?, false)
                 ON CONFLICT (key, language_code) DO UPDATE SET text = EXCLUDED.text, is_auto = false, updated_at = now()",
            [$key, $code, $text]);
    }
    audit($me, 'update', 'ui_translations', ['key' => $key, 'lang' => $code], $before,
        db_one("SELECT * FROM ui_translations WHERE key = ? AND language_code = ?", [$key, $code]));
    api_ok();
}

api_fail('bad_action');
```

### `tools/seed_ui.php`

```php
<?php
/* Готовые переводы интерфейса (lang/seed/*.json — ru, he, ar из Ramada) → таблица ui_translations.
 * Запускается при установке и после обновления (deploy.sh). Ручные правки на странице «Языки» не затираются:
 * обновляются только тексты, которые переведены автоматически или ещё не заведены.
 *   php tools/seed_ui.php          — только готовые переводы
 *   php tools/seed_ui.php --fill   — и сразу перевести недостающее на все включённые языки (нужен интернет)
 */
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require_once __DIR__ . '/../backend/core/db.php';
require_once __DIR__ . '/../backend/core/translate.php';
require_once __DIR__ . '/../backend/core/ui_text.php';

$total = 0;
foreach (glob(__DIR__ . '/../lang/seed/*.json') as $file) {
    $lang = basename($file, '.json');
    $texts = json_decode((string)file_get_contents($file), true);
    if (!is_array($texts)) {
        fwrite(STDERR, "Не читается: $file\n");
        exit(1);
    }
    if (!db_value("SELECT 1 FROM languages WHERE code = ?", [$lang])) {
        echo "$lang: такого языка нет в таблице languages, пропускаю\n";
        continue;
    }
    $n = 0;
    db_tx(function () use ($texts, $lang, &$n) {
        foreach ($texts as $key => $text) {
            $n += db_exec("INSERT INTO ui_translations (key, language_code, text, is_auto) VALUES (?, ?, ?, false)
                           ON CONFLICT (key, language_code) DO UPDATE SET text = EXCLUDED.text, is_auto = false, updated_at = now()
                           WHERE ui_translations.is_auto AND ui_translations.text IS DISTINCT FROM EXCLUDED.text",
                [$key, $lang, $text])->rowCount();
        }
    });
    echo "$lang: " . count($texts) . " текстов, записано $n\n";
    $total += $n;
}
echo "Готово, записано $total.\n";

if (in_array('--fill', $argv, true)) {
    foreach (db_all("SELECT code FROM languages WHERE is_active AND code <> 'en' ORDER BY sort_order") as $l) {
        $code = $l['code'];
        if (!db_value("SELECT pg_try_advisory_lock(hashtext(?))", ['ui_fill:' . $code])) {
            echo "$code: уже переводится другим процессом\n";
            continue;
        }
        try {
            ui_fill_language($code);
        } finally {
            db_exec("SELECT pg_advisory_unlock(hashtext(?))", ['ui_fill:' . $code]);
        }
        echo "$code: не хватает " . ui_missing_count($code) . "\n";
    }
}
```

### `frontend/app/src/i18n.js`

```js
// Тексты интерфейса на любом языке.
// Английские — основа, лежат в lang/en.json и входят в сборку. Остальные языки приходят с сервера
// (backend/api/ui_texts.php: переводы из таблицы ui_translations, недостающие сервер переводит сам)
// и запоминаются в браузере, чтобы интерфейс открывался сразу и без сети.
//
//   uiText('worker', lang)  — словарь раздела: { title: '…', … }; тексты с {1}, {2} — функции t.key(a, b)
//   loadUi(lang)            — подгрузить язык (вызывает App перед сменой языка)
//   useUi()                 — перерисовать компонент, когда тексты обновились
//   isRtl(lang), langName(code), languageList(), localeOf(lang)
import { useEffect, useState } from 'react';
import EN from '../../../lang/en.json';

const STORE = 'hotelapp_ui_';
const RTL_FALLBACK = ['he', 'ar', 'fa', 'ur', 'yi', 'ps', 'dv', 'ku'];
const texts = {};        // lang → { key: text }
const dicts = {};        // `${lang}:${ns}` → готовый словарь раздела
let languages = readStore('languages') || [];
const listeners = new Set();

function readStore(name) {
    try {
        const raw = localStorage.getItem(STORE + name);
        return raw ? JSON.parse(raw) : null;
    } catch {
        return null;
    }
}

function writeStore(name, value) {
    try { localStorage.setItem(STORE + name, JSON.stringify(value)); } catch { /* не страшно */ }
}

function textsOf(lang) {
    if (lang === 'en') return {};
    if (!texts[lang]) texts[lang] = readStore('texts_' + lang)?.texts || {};
    return texts[lang];
}

const withArgs = (s) => (...a) => s.replace(/\{(\d)\}/g, (_, i) => (a[i - 1] ?? ''));

export function uiText(ns, lang) {
    const id = `${lang}:${ns}`;
    if (dicts[id]) return dicts[id];
    const tr = textsOf(lang);
    const prefix = ns + '.';
    const out = {};
    for (const key of Object.keys(EN)) {
        if (!key.startsWith(prefix)) continue;
        const s = tr[key] || EN[key];
        out[key.slice(prefix.length)] = /\{1\}/.test(EN[key]) ? withArgs(s) : s;
    }
    dicts[id] = out;
    return out;
}

// Подгружает тексты языка с сервера. Пока ждём, интерфейс уже работает на сохранённых (или английских).
export async function loadUi(lang) {
    if (!lang) return;
    const saved = readStore('texts_' + lang);
    try {
        const res = await fetch(`/backend/api/ui_texts.php?lang=${encodeURIComponent(lang)}${saved?.version ? `&have=${encodeURIComponent(saved.version)}` : ''}`, { cache: 'no-store' });
        const data = await res.json();
        if (!data.success) return;
        if (data.languages) {
            languages = data.languages;
            writeStore('languages', languages);
        }
        if (data.texts && lang !== 'en') {
            texts[lang] = data.texts;
            writeStore('texts_' + lang, { version: data.version, texts: data.texts });
        }
        for (const id of Object.keys(dicts)) if (id.startsWith(lang + ':')) delete dicts[id];
        listeners.forEach((fn) => fn());
    } catch { /* без сети — сохранённые тексты */ }
}

// Компонент перерисуется, когда придут тексты или список языков
export function useUi() {
    const [, setN] = useState(0);
    useEffect(() => {
        const fn = () => setN((n) => n + 1);
        listeners.add(fn);
        return () => listeners.delete(fn);
    }, []);
}

export function languageList() {
    return languages.length ? languages : [{ code: 'en', name: 'English', rtl: false }];
}

export function isRtl(lang) {
    const l = languages.find((x) => x.code === lang);
    return l ? !!l.rtl : RTL_FALLBACK.includes(String(lang).split('-')[0]);
}

export const dirOf = (lang) => (isRtl(lang) ? 'rtl' : 'ltr');

export function langName(code) {
    return languages.find((x) => x.code === code)?.name || String(code).toUpperCase();
}

// Для toLocaleString: русский — ru-RU (иначе формат даты другой), остальные — как есть
export function localeOf(lang) {
    return { ru: 'ru-RU', he: 'he-IL', ar: 'ar-SA', en: 'en-US' }[lang] || lang;
}
```

### `frontend/app/src/flags.js`

```js
// Флаги языков: язык → страна (флаг). Регион в коде (pt-BR, zh-TW) берёт флаг региона.
// Картинки — flag-icons (SVG), в сборку попадают только перечисленные страны и грузятся по требованию.
const FLAG_URLS = import.meta.glob('/node_modules/flag-icons/flags/4x3/{ae,af,al,am,ar,at,au,az,ba,bd,be,bg,br,by,ca,ch,cl,cn,co,cz,de,dk,dz,ee,eg,es,es-ct,es-ga,es-pv,et,fi,fr,gb,gb-wls,ge,gr,hk,hr,ht,hu,id,ie,il,in,iq,ir,is,it,jo,jp,ke,kg,kh,kr,kz,la,lb,lk,lt,lu,lv,ma,mg,mk,mm,mn,mt,mx,my,ng,nl,no,np,pe,ph,pk,pl,pt,ro,rs,ru,rw,sa,se,sg,si,sk,so,sy,th,tj,tm,tn,tr,tw,ua,us,uz,ve,vn,za}.svg', { query: '?url', import: 'default', eager: true });

const LANG_COUNTRY = {
    af: 'za',
    am: 'et',
    ar: 'sa',
    az: 'az',
    be: 'by',
    bg: 'bg',
    bn: 'bd',
    bs: 'ba',
    ca: 'es-ct',
    cs: 'cz',
    cy: 'gb-wls',
    da: 'dk',
    de: 'de',
    el: 'gr',
    en: 'gb',
    es: 'es',
    et: 'ee',
    eu: 'es-pv',
    fa: 'ir',
    fi: 'fi',
    fil: 'ph',
    fr: 'fr',
    ga: 'ie',
    gl: 'es-ga',
    gu: 'in',
    ha: 'ng',
    haw: 'us',
    he: 'il',
    hi: 'in',
    hr: 'hr',
    ht: 'ht',
    hu: 'hu',
    hy: 'am',
    id: 'id',
    ig: 'ng',
    is: 'is',
    it: 'it',
    ja: 'jp',
    ka: 'ge',
    kk: 'kz',
    km: 'kh',
    kn: 'in',
    ko: 'kr',
    ku: 'iq',
    ky: 'kg',
    lb: 'lu',
    lo: 'la',
    lt: 'lt',
    lv: 'lv',
    mg: 'mg',
    mk: 'mk',
    ml: 'in',
    mn: 'mn',
    mr: 'in',
    ms: 'my',
    mt: 'mt',
    my: 'mm',
    nb: 'no',
    ne: 'np',
    nl: 'nl',
    no: 'no',
    pa: 'in',
    pl: 'pl',
    ps: 'af',
    pt: 'pt',
    ro: 'ro',
    ru: 'ru',
    rw: 'rw',
    si: 'lk',
    sk: 'sk',
    sl: 'si',
    so: 'so',
    sq: 'al',
    sr: 'rs',
    sv: 'se',
    sw: 'ke',
    ta: 'in',
    te: 'in',
    tg: 'tj',
    th: 'th',
    tk: 'tm',
    tl: 'ph',
    tr: 'tr',
    tt: 'ru',
    uk: 'ua',
    ur: 'pk',
    uz: 'uz',
    vi: 'vn',
    yi: 'il',
    yo: 'ng',
    zh: 'cn',
    zu: 'za',
};

/** URL флага для языка или null (нет подходящего флага). */
export function flagUrl(code) {
    const [lang, region] = String(code || '').toLowerCase().split('-');
    const url = (c) => (c ? FLAG_URLS[`/node_modules/flag-icons/flags/4x3/${c}.svg`] : null);
    return url(region?.length === 2 ? region : null) || url(LANG_COUNTRY[lang]) || null;
}
```

### `frontend/app/src/components/LangPicker.jsx`

```jsx
import { useState, useEffect } from 'react';
import { flagUrl } from '../flags';
import { langName, dirOf } from '../i18n';

// Выбор языка: кнопка «флаг + название ▾», по нажатию — плитка всех языков по алфавиту с флагами.

export function LangFlag({ code, size = 22 }) {
    const url = flagUrl(code);
    const h = Math.round(size * 0.75);
    if (!url) {
        return <span aria-hidden="true" style={{ width: size, height: h, flex: 'none', borderRadius: 3, background: '#d9dee6', color: '#3f4752', fontSize: Math.round(h * 0.6), fontWeight: 'bold', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>{String(code).slice(0, 2).toUpperCase()}</span>;
    }
    return <img src={url} alt="" width={size} height={h} style={{ flex: 'none', borderRadius: 3, objectFit: 'cover', boxShadow: '0 0 0 1px rgba(0,0,0,0.12)' }} />;
}

/** langs — коды языков; value — текущий; onPick(code). */
export default function LangPicker({ value, langs, onPick, style }) {
    const [open, setOpen] = useState(false);
    const [q, setQ] = useState('');
    useEffect(() => {
        if (!open) return undefined;
        const onKey = (e) => { if (e.key === 'Escape') setOpen(false); };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, [open]);

    const sorted = [...langs].sort((a, b) => langName(a).localeCompare(langName(b), 'en'));
    const shown = q.trim() ? sorted.filter(c => `${langName(c)} ${c}`.toLowerCase().includes(q.trim().toLowerCase())) : sorted;
    const pick = (c) => { setOpen(false); setQ(''); onPick(c); };

    return (
        <>
            <button type="button" onClick={() => setOpen(true)} aria-haspopup="dialog"
                style={{ display: 'inline-flex', alignItems: 'center', gap: '10px', padding: '9px 14px', borderRadius: '10px', border: '1px solid #cfc4ba', background: '#fff', color: '#3f3530', fontSize: '17px', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', ...style }}>
                <LangFlag code={value} />
                <span dir={dirOf(value)}>{langName(value)}</span>
                <span aria-hidden="true" style={{ fontSize: '12px', opacity: 0.6 }}>▼</span>
            </button>
            {open && (
                <div role="dialog" aria-modal="true" onClick={() => setOpen(false)}
                    style={{ position: 'fixed', inset: 0, background: 'rgba(20, 24, 32, 0.55)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }}>
                    <div onClick={e => e.stopPropagation()}
                        style={{ background: '#fff', borderRadius: '14px', padding: '18px', width: '100%', maxWidth: '640px', maxHeight: '85vh', display: 'flex', flexDirection: 'column', gap: '12px', boxShadow: '0 10px 40px rgba(0,0,0,0.3)', boxSizing: 'border-box' }}>
                        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                            {sorted.length > 9 && (
                                <input autoFocus value={q} onChange={e => setQ(e.target.value)} placeholder="🔍"
                                    style={{ flex: 1, padding: '10px 12px', fontSize: '16px', borderRadius: '8px', border: '1px solid #cfc4ba', minWidth: 0 }} />
                            )}
                            <button type="button" onClick={() => setOpen(false)} aria-label="×"
                                style={{ marginInlineStart: 'auto', width: '40px', height: '40px', borderRadius: '50%', border: 'none', background: '#f1ece7', fontSize: '20px', cursor: 'pointer' }}>×</button>
                        </div>
                        <div style={{ overflowY: 'auto', display: 'grid', gap: '8px', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))' }}>
                            {shown.map(c => (
                                <button key={c} type="button" onClick={() => pick(c)} aria-pressed={c === value}
                                    style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '12px', borderRadius: '10px', cursor: 'pointer', fontSize: '16px', fontFamily: 'inherit', textAlign: 'start',
                                        border: c === value ? '2px solid var(--brand-button, #1f3a5f)' : '1px solid #e2ddd8', background: c === value ? '#eef2f7' : '#fff', color: '#2b2320' }}>
                                    <LangFlag code={c} size={28} />
                                    <span dir={dirOf(c)} style={{ minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>{langName(c)}</span>
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            )}
        </>
    );
}
```

### `frontend/app/src/components/admin/AdminLanguages.jsx`

```jsx
import { useState, useEffect, useCallback } from 'react';
import { tr, trNs, api, errText, S, Message, Ic } from './adminUi';

// Админка → Языки (только владелец системы): языки системы и тексты интерфейса на них.
// Новый язык добавляется строкой: тексты интерфейса сервер переводит сам, сразу после сохранения.
// Любой перевод можно поправить; поправленное автоперевод больше не трогает.

const API = '/backend/api/admin_languages.php';
const blank = { code: '', name: '', native_name: '', rtl: false, active: true, sort_order: 100, isNew: true };

export default function AdminLanguages({ lang }) {
    const t = { ...tr(lang), ...trNs('langs', lang) };
    const [data, setData] = useState(null);
    const [form, setForm] = useState(null);
    const [msg, setMsg] = useState(null);
    const [busy, setBusy] = useState(false);
    const [edit, setEdit] = useState(null);       // код языка, тексты которого правим
    const [kick, setKick] = useState(0);          // когда запустили перевод: перевод начинается чуть позже ответа

    const load = useCallback(async () => {
        const d = await api(`${API}?action=list`);
        if (d.success) setData(d); else setMsg({ ok: false, text: errText(t, d) });
    }, [lang]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { load(); }, [load]);

    // Пока идёт автоперевод, обновляем счётчики
    const filling = !!data?.languages.some(l => l.filling);
    useEffect(() => {
        if (!filling && !kick) return;
        const id = setInterval(() => {
            load();
            if (Date.now() - kick > 10000) setKick(0);
        }, 3000);
        return () => clearInterval(id);
    }, [filling, kick, load]);

    const post = async (action, body, okText) => {
        setBusy(true);
        setMsg(null);
        const d = await api(`${API}?action=${action}`, body);
        setBusy(false);
        if (!d.success) { setMsg({ ok: false, text: errText(t, d) }); return false; }
        setMsg({ ok: true, text: okText });
        if (d.filling) setKick(Date.now());
        await load();
        loadUi(lang); // список языков в меню и на экране входа
        return true;
    };

    const save = async (e) => {
        e.preventDefault();
        if (await post('save', form, form.isNew ? t.added : t.saved)) setForm(null);
    };

    if (!data) return <div style={{ padding: '30px', textAlign: 'center', color: '#6e635b' }}>{t.loading}</div>;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', textAlign: 'start' }}>
            <div className="ad-hint">{t.intro}</div>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
                <button type="button" className="ad-btn blue" onClick={() => { setForm({ ...blank }); setMsg(null); }}>{t.add}</button>
                <span className="ad-hint">{t.provider}: <b>{data.provider}</b></span>
            </div>
            <Message msg={msg} />

            {form && (
                <form onSubmit={save} className="ad-card" style={{ display: 'grid', gap: '10px', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
                    <label className="ad-lab">{t.code}
                        <input className="ad-fld" dir="ltr" required disabled={!form.isNew} value={form.code} placeholder="fr, de, uk, zh-CN"
                            onChange={e => setForm(f => ({ ...f, code: e.target.value.trim() }))} />
                    </label>
                    <label className="ad-lab">{t.name_en}
                        <input className="ad-fld" dir="ltr" required value={form.name} placeholder="French" onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
                    </label>
                    <label className="ad-lab">{t.native}
                        <input className="ad-fld" dir="auto" value={form.native_name || ''} placeholder="Français" onChange={e => setForm(f => ({ ...f, native_name: e.target.value }))} />
                    </label>
                    <label className="ad-lab">{t.order}
                        <input className="ad-fld" type="number" value={form.sort_order} onChange={e => setForm(f => ({ ...f, sort_order: Number(e.target.value) }))} />
                    </label>
                    <label style={{ display: 'inline-flex', gap: '8px', alignItems: 'center' }}>
                        <input type="checkbox" checked={!!form.rtl} onChange={e => setForm(f => ({ ...f, rtl: e.target.checked }))} /> {t.rtl}
                    </label>
                    <label style={{ display: 'inline-flex', gap: '8px', alignItems: 'center' }}>
                        <input type="checkbox" checked={!!form.active} disabled={form.code === 'en'} onChange={e => setForm(f => ({ ...f, active: e.target.checked }))} /> {t.active}
                    </label>
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'flex-end' }}>
                        <button type="submit" className="ad-btn blue" disabled={busy}>{t.save}</button>
                        <button type="button" className="ad-btn" onClick={() => setForm(null)}>{t.cancel}</button>
                    </div>
                </form>
            )}

            <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'start' }}>
                    <thead>
                        <tr>
                            {[t.language, t.progress, t.hotels, t.actions].map(h => <th key={h} style={{ ...S.th, textAlign: 'start' }}>{h}</th>)}
                        </tr>
                    </thead>
                    <tbody>
                        {data.languages.map(l => {
                            const done = l.translated >= data.total;
                            return (
                                <tr key={l.code} style={{ opacity: l.active ? 1 : 0.55 }}>
                                    <td style={S.td}>
                                        <b dir="auto">{l.native_name || l.name}</b> <span className="ad-hint">{l.name} · <code>{l.code}</code>{l.rtl ? ' · RTL' : ''}</span>
                                        {!l.active && <div className="ad-hint">{t.inactive}</div>}
                                    </td>
                                    <td style={S.td}>
                                        {l.code === 'en' ? <span className="ad-hint">{t.base}</span> : (
                                            <>
                                                <span style={S.badge(done ? '#e7f6ec' : '#fff4e0', done ? '#1f6b3d' : '#8a5a12')}>{l.translated} / {data.total}</span>
                                                {l.filling && <span className="ad-hint" style={{ marginInlineStart: '8px' }}>{t.translating}</span>}
                                                {l.auto > 0 && <div className="ad-hint">{t.auto_n(l.auto)}</div>}
                                            </>
                                        )}
                                    </td>
                                    <td style={{ ...S.td, color: '#7d726a' }}>{l.hotels || '—'}</td>
                                    <td style={{ ...S.td, whiteSpace: 'nowrap' }}>
                                        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                                            <button type="button" className="ad-btn" onClick={() => { setForm({ ...l, isNew: false }); setMsg(null); }}><Ic n="edit" /></button>
                                            {l.code !== 'en' && <button type="button" className="ad-btn" onClick={() => setEdit(edit === l.code ? null : l.code)}>{t.texts}</button>}
                                            {l.code !== 'en' && !done && <button type="button" className="ad-btn" disabled={busy} onClick={() => post('fill', { code: l.code }, t.fill_started)}>{t.fill}</button>}
                                            {l.code !== 'en' && l.auto > 0 && (
                                                <button type="button" className="ad-btn" disabled={busy}
                                                    onClick={() => window.confirm(t.redo_confirm) && post('fill', { code: l.code, redo: 1 }, t.fill_started)}>{t.redo}</button>
                                            )}
                                        </div>
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>

            {edit && <LanguageTexts key={edit} t={t} code={edit} name={data.languages.find(l => l.code === edit)?.name}
                rtl={!!data.languages.find(l => l.code === edit)?.rtl} onChanged={load} />}
        </div>
    );
}

// Тексты интерфейса одного языка: английский рядом, поправить перевод, вернуть автоперевод
function LanguageTexts({ t, code, name, rtl, onChanged }) {
    const [rows, setRows] = useState(null);
    const [q, setQ] = useState('');
    const [onlyAuto, setOnlyAuto] = useState(false);
    const [drafts, setDrafts] = useState({});
    const [msg, setMsg] = useState(null);

    const load = useCallback(async () => {
        const d = await api(`${API}?action=texts&code=${encodeURIComponent(code)}`);
        if (d.success) setRows(d.rows); else setMsg({ ok: false, text: errText(t, d) });
    }, [code]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { load(); }, [load]);

    const saveText = async (key, text) => {
        const d = await api(`${API}?action=text`, { code, key, text });
        if (!d.success) {
            setMsg({ ok: false, text: d.message === 'placeholders' ? t.placeholders((d.need || []).join(' ')) : errText(t, d) });
            return;
        }
        setMsg({ ok: true, text: t.saved });
        setDrafts(dr => { const n = { ...dr }; delete n[key]; return n; });
        await load();
        onChanged();
    };

    if (!rows) return <div style={{ padding: '20px', color: '#6e635b' }}>{t.loading}</div>;
    const ql = q.trim().toLowerCase();
    const shown = rows.filter(r => (!onlyAuto || r.auto !== false)
        && (!ql || `${r.key} ${r.en} ${r.text || ''}`.toLowerCase().includes(ql))).slice(0, 300);

    return (
        <div className="ad-card" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <b>{t.texts_of(name)}</b>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
                <input className="ad-fld" style={{ flex: '1 1 220px', width: 'auto' }} placeholder={t.search} value={q} onChange={e => setQ(e.target.value)} />
                <label style={{ display: 'inline-flex', gap: '6px', alignItems: 'center' }}>
                    <input type="checkbox" checked={onlyAuto} onChange={e => setOnlyAuto(e.target.checked)} /> {t.only_auto}
                </label>
            </div>
            <div className="ad-hint">{t.texts_hint}</div>
            <Message msg={msg} />
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {shown.map(r => {
                    const draft = drafts[r.key];
                    const value = draft ?? r.text ?? '';
                    return (
                        <div key={r.key} style={{ display: 'grid', gap: '6px', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', padding: '8px', background: '#fff', borderRadius: '10px', border: '1px solid #ebe3dc' }}>
                            <div style={{ minWidth: 0 }}>
                                <div className="ad-hint" style={{ fontSize: '12px' }}><code>{r.key}</code></div>
                                <div dir="ltr" style={{ overflowWrap: 'anywhere' }}>{r.en}</div>
                            </div>
                            <div style={{ display: 'flex', gap: '6px', alignItems: 'flex-start', minWidth: 0 }}>
                                <textarea className="ad-fld" style={{ minHeight: '42px', resize: 'vertical', fontFamily: 'inherit' }} dir={rtl ? 'rtl' : 'ltr'} lang={code}
                                    value={value} placeholder={r.en} onChange={e => setDrafts(d => ({ ...d, [r.key]: e.target.value }))} />
                                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                    {draft !== undefined && draft !== (r.text ?? '') && <button type="button" className="ad-btn blue" onClick={() => saveText(r.key, draft)}><Ic n="save" /></button>}
                                    {r.auto === false && <button type="button" className="ad-btn" title={t.reset} onClick={() => saveText(r.key, '')}>↺</button>}
                                </div>
                            </div>
                            <div className="ad-hint" style={{ fontSize: '12px' }}>{r.auto === null ? t.st_missing : r.auto ? t.st_auto : t.st_manual}</div>
                        </div>
                    );
                })}
                {shown.length === 0 && <div className="ad-hint">{t.empty}</div>}
            </div>
        </div>
    );
}
```
