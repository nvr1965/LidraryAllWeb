
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

