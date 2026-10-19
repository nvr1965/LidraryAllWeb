# Блок перевода интерфейса (Hotels Maintenance)

Выдержка из ветки feature/postgresql. Ключей и паролей тут нет: secrets.php и config.local.php в архив не входят.

## Как устроено
- `lang/en.json` — основа: все тексты интерфейса на английском, ключи вида `раздел.ключ`.
- `lang/seed/{ru,he,ar}.json` — готовые переводы, которые загружаются в базу.
- `db/i18n_schema.sql` — таблицы: `languages` (языки), `ui_translations` (переводы интерфейса, `is_auto` = переведено машиной), `translation_cache` (кеш перевода свободного текста).
- `backend/core/ui_text.php` — тексты на сервере (`ui_t`), догрузка недостающих переводов языка (`ui_fill_language`).
- `backend/core/translate.php` — автоперевод: Gemini, Google или MyMemory (выбор по ключам в secrets.php), кеш, перевод данных отеля и заметок на лету.
- `backend/core/gemini_ocr.php` — общий вызов Gemini (нужен translate.php).
- `backend/api/ui_texts.php` — отдаёт клиенту тексты на нужном языке (с версией для кеша).
- `backend/api/admin_languages.php` — админка языков: добавить язык, перевести, поправить текст вручную.
- `tools/seed_ui.php` — загрузить seed-переводы в базу (`--fill` — допереводить недостающее).
- `frontend/app/src/i18n.js` — клиент: `uiText(ns, lang)`, `loadUi`, `dirOf`, `localeOf`, кеш в браузере.
- `frontend/app/src/components/LangPicker.jsx`, `flags.js` — выбор языка плиткой с флагами (пакет flag-icons).
- `frontend/app/src/components/admin/AdminLanguages.jsx` — экран «Языки».

## Зависимости вне архива
`backend/core/api.php`, `db.php`, `config.php` (подключение к базе, ответы API), npm-пакет `flag-icons`.
