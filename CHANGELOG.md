# Changelog

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версии следуют [Semantic Versioning](https://semver.org/lang/ru/).

## [1.1.0] — 2026-09-19

### Добавлено
- Действие `rustore_version_status` — статус последней версии приложения.
- Действие `rustore_publish_version` — ручная публикация прошедшей модерацию версии.
- Действие `rustore_archive_version` — архивирование версии.
- Действие `rustore_publish_settings` — изменение типа публикации, даты и процента раскатки.
- Поэтапная раскатка через `partial_value` (5/10/25/50/75/100).
- Метаданные черновика: `app_name`, `app_type`, `age_legal`, `short_description`,
  `full_description`, `moder_info`, `price_value`, `whats_new`.
- Флаги `remove_existing_drafts` и `submit_for_moderation`, параметр `priority_update`.
- Настраиваемый `timeout` и повтор запроса при сетевых сбоях.
- `RUSTORE_VERSION_ID` и `RUSTORE_VERSION_STATUS` в `lane_context`.

### Исправлено
- `publish_datetime` не передавался в запрос создания черновика, из-за чего
  `publish_type: "DELAYED"` всегда завершался ошибкой.
- Плагин не загружался вместе с современным fastlane: `faraday_middleware`
  требует Faraday 1.x, а fastlane использует Faraday 2.x.
- В gemspec не было ни одной runtime-зависимости, поэтому в чистом окружении
  плагин падал с `cannot load such file`.
- Токен `Public-Token` попадал в stderr при каждом запуске: HTTP-логгер был
  включён безусловно. Теперь он включается через `RUSTORE_DEBUG`, а токен,
  подпись и JWE маскируются.
- `key_id` и `private_key` не были помечены `sensitive`, из-за чего fastlane
  печатал их в сводке параметров.
- Лимит changelog был 500 символов вместо документированных 5000.
- Ответы не-JSON (HTML-страницы ошибок, 502 от прокси) роняли плагин на `#dig`.
- Список черновиков читался только с первой страницы, остальные не удалялись.
- Статус HTTP не проверялся: сбой публикации выглядел как успех.
- Ключи PKCS#8 в виде голого Base64 не читались.
- Отсутствовала проверка существования файлов сборки и changelog.

### Изменено
- Код разделён на слои: `Rustore::Signer`, `Rustore::Client`, `Rustore::Api`
  и фасад `UploadToRuStoreHelper`, сохраняющий прежний публичный интерфейс.
- Минимальная версия Ruby — 3.2: зависимости fastlane (google-apis-*, googleauth,
  signet, excon) больше не собираются на 3.1.
- CI переведён на Ruby 3.2/3.3/3.4 и `actions/checkout@v4`.

## [1.0.7]

- Увеличен таймаут запросов.
