# fastlane-plugin-upload_to_ru_store

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-upload_to_ru_store)

Fastlane-плагин для публикации Android-приложений в **RuStore**: загрузка AAB/APK,
поэтапная раскатка, отложенный релиз, ручная публикация и архивирование версий.

---

## Содержание

- [Установка](#установка)
- [Быстрый старт](#быстрый-старт)
- [Получение ключей](#получение-ключей)
- [Действия](#действия)
  - [upload_to_ru_store](#upload_to_ru_store)
  - [rustore_version_status](#rustore_version_status)
  - [rustore_publish_version](#rustore_publish_version)
  - [rustore_publish_settings](#rustore_publish_settings)
  - [rustore_archive_version](#rustore_archive_version)
- [Рецепты](#рецепты)
- [Переменные окружения](#переменные-окружения)
- [Отладка](#отладка)
- [Ограничения RuStore](#ограничения-rustore)
- [Обновление с 1.0.x](#обновление-с-10x)
- [Разработка](#разработка)

---

## Установка

```bash
fastlane add_plugin upload_to_ru_store
```

Требуется Ruby >= 3.2 и fastlane >= 2.240.

---

## Быстрый старт

```ruby
lane :publish_to_rustore do
  upload_to_ru_store(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    aab: "app/build/outputs/bundle/release/app-release.aab",
    changelog_path: "metadata/android/ru-RU/changelog.txt"
  )
end
```

Что происходит под капотом:

1. подпись `key_id + timestamp` по RSA-SHA512, обмен на JWE-токен;
2. удаление незавершённых черновиков приложения;
3. создание черновика с метаданными и настройками публикации;
4. загрузка сборки (AAB, либо GMS APK и опционально HMS APK);
5. отправка черновика на модерацию.

Шаги 2 и 5 отключаются флагами `remove_existing_drafts` и `submit_for_moderation`.

---

## Получение ключей

В консоли RuStore: **Настройки → Ключи доступа → Создать ключ**. Вы получите
идентификатор ключа (`key_id`) и приватный RSA-ключ.

`private_key` принимается в любом из форматов:

- PEM с заголовком `-----BEGIN PRIVATE KEY-----` (PKCS#8);
- PEM с заголовком `-----BEGIN RSA PRIVATE KEY-----` (PKCS#1);
- голый Base64 без заголовков — формат определяется автоматически по структуре DER.

Последний вариант удобен для CI: ключ кладётся в секрет одной строкой.

```bash
RUSTORE_PRIVATE_KEY=$(tr -d '\n' < key.pem)
```

---

## Действия

### upload_to_ru_store

Полный цикл выпуска: черновик → сборка → модерация. Возвращает `versionId`
созданного черновика и кладёт его в `lane_context[SharedValues::RUSTORE_VERSION_ID]`.

#### Обязательные параметры

| Параметр | Описание |
|---|---|
| `package_name` | Идентификатор пакета, например `com.example.app` |
| `key_id` | Идентификатор ключа доступа RuStore |
| `private_key` | Приватный RSA-ключ |

Нужно указать хотя бы `aab` или `gms_apk`.

#### Сборки

| Параметр | Описание |
|---|---|
| `aab` | Путь к Android App Bundle. Если указан, APK не загружаются |
| `gms_apk` | Путь к APK с Google Mobile Services |
| `hms_apk` | Путь к APK с Huawei Mobile Services, грузится дополнительно |

#### Публикация

| Параметр | Значения | Описание |
|---|---|---|
| `publish_type` | `MANUAL`, `INSTANTLY`, `DELAYED` | Тип публикации |
| `publish_datetime` | ISO8601 | Обязателен при `DELAYED`. От 24 часов до 60 дней от момента отправки на модерацию |
| `partial_value` | `5`, `10`, `25`, `50`, `75`, `100` | Процент поэтапной раскатки |
| `priority_update` | целое число | Приоритет обновления при отправке на модерацию |

#### Метаданные черновика

| Параметр | Лимит | Описание |
|---|---|---|
| `changelog_path` | 5000 символов | Путь к файлу «Что нового» |
| `whats_new` | 5000 символов | То же самое, но строкой |
| `app_name` | 50 символов | Название приложения |
| `app_type` | `MAIN`, `GAMES` | Тип приложения |
| `age_legal` | `0+`, `6+`, `12+`, `16+`, `18+` | Возрастной рейтинг |
| `short_description` | 80 символов | Краткое описание |
| `full_description` | 4000 символов | Полное описание |
| `moder_info` | 180 символов | Комментарий для модератора |
| `price_value` | целое | Цена в копейках для платных приложений |

#### Поведение

| Параметр | По умолчанию | Описание |
|---|---|---|
| `remove_existing_drafts` | `true` | Удалять существующие черновики перед созданием нового |
| `submit_for_moderation` | `true` | Отправлять черновик на модерацию |
| `timeout` | `600` | Таймаут чтения ответа, секунды |

---

### rustore_version_status

Возвращает Hash с данными последней версии: `versionId`, `versionCode`,
`versionName`, `versionStatus`, `publishType`, `partialValue` и остальные поля RuStore.
Если версий нет — возвращает `nil`.

```ruby
version = rustore_version_status(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"]
)

UI.message("Статус: #{version['versionStatus']}")
```

Параметры: `package_name`, `key_id`, `private_key`, `testing_type` (`ALL`/`RELEASE`/`ALPHA`), `timeout`.

Возможные значения `versionStatus`:

| Статус | Значение |
|---|---|
| `DRAFT` | черновик |
| `AUTO_CHECK` | антивирусная проверка |
| `AUTO_CHECK_FAILED` | не прошла антивирусную проверку |
| `MODERATION` | ждёт модерации |
| `TAKEN_FOR_MODERATION` | взята модератором |
| `READY_FOR_PUBLICATION` | прошла модерацию |
| `REJECTED_BY_MODERATOR` | отклонена модератором |
| `REJECTED_BY_SECURITY` | отклонена службой безопасности |
| `ACTIVE` | опубликована |
| `PARTIAL_ACTIVE` | опубликована частично |
| `PREVIOUS_ACTIVE` | предыдущая активная версия |
| `ARCHIVED` | архивирована |
| `DELETED_DRAFT` | удалённый черновик |

---

### rustore_publish_version

Публикует версию, которая прошла модерацию и была создана с `publish_type: "MANUAL"`.
Без `version_id` берёт последнюю версию приложения.

```ruby
rustore_publish_version(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"]
)
```

---

### rustore_publish_settings

Меняет настройки публикации уже существующей версии: тип, дату отложенного
релиза, процент раскатки.

```ruby
rustore_publish_settings(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"],
  version_id: 12345,
  partial_value: 50
)
```

RuStore разрешает только увеличивать процент раскатки; `100` означает полный релиз.

---

### rustore_archive_version

Архивирует версию. RuStore принимает архивирование только для статусов
`READY_FOR_PUBLICATION` и `REJECTED_BY_MODERATOR`.

```ruby
rustore_archive_version(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"],
  version_id: 12345
)
```

---

## Рецепты

### Поэтапная раскатка

Выпуск на 10% аудитории, затем расширение:

```ruby
lane :rollout_start do
  upload_to_ru_store(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    aab: "app-release.aab",
    publish_type: "INSTANTLY",
    partial_value: 10
  )
end

lane :rollout_expand do |options|
  version = rustore_version_status(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"]
  )

  rustore_publish_settings(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    version_id: version["versionId"],
    partial_value: options[:percent].to_i
  )
end
```

### Отложенная публикация

```ruby
upload_to_ru_store(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"],
  aab: "app-release.aab",
  publish_type: "DELAYED",
  publish_datetime: (Time.now + 3 * 24 * 3600).iso8601
)
```

### Ручная публикация после проверки

```ruby
lane :stage do
  upload_to_ru_store(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    aab: "app-release.aab",
    publish_type: "MANUAL"
  )
end

lane :go_live do
  version = rustore_version_status(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"]
  )

  UI.user_error!("Версия ещё не прошла модерацию: #{version['versionStatus']}") unless
    version["versionStatus"] == "READY_FOR_PUBLICATION"

  rustore_publish_version(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    version_id: version["versionId"]
  )
end
```

### Черновик без отправки на модерацию

Полезно, когда сборку нужно залить заранее, а метаданные дозаполнить в консоли.

```ruby
upload_to_ru_store(
  package_name: "com.example.app",
  key_id: ENV["RUSTORE_KEY_ID"],
  private_key: ENV["RUSTORE_PRIVATE_KEY"],
  aab: "app-release.aab",
  submit_for_moderation: false
)
```

---

## Переменные окружения

Каждый параметр читается из переменной окружения, что удобно в CI:

| Переменная | Параметр |
|---|---|
| `RUSTORE_PACKAGE_NAME` | `package_name` |
| `RUSTORE_KEY_ID` | `key_id` |
| `RUSTORE_PRIVATE_KEY` | `private_key` |
| `RUSTORE_PUBLISH_TYPE` | `publish_type` |
| `RUSTORE_PUBLISH_DATETIME` | `publish_datetime` |
| `RUSTORE_PARTIAL_VALUE` | `partial_value` |
| `RUSTORE_AAB` | `aab` |
| `RUSTORE_GMS_APK` | `gms_apk` |
| `RUSTORE_HMS_APK` | `hms_apk` |
| `RUSTORE_CHANGELOG_PATH` | `changelog_path` |
| `RUSTORE_VERSION_ID` | `version_id` |
| `RUSTORE_TESTING_TYPE` | `testing_type` |
| `RUSTORE_TIMEOUT` | `timeout` |

`key_id` и `private_key` помечены как `sensitive`, поэтому fastlane не печатает
их в сводке параметров.

---

## Отладка

```bash
RUSTORE_DEBUG=1 bundle exec fastlane publish_to_rustore
```

Включает подробный HTTP-лог. Заголовок `Public-Token`, поле `signature` и `jwe`
в выводе маскируются.

При сетевых сбоях и ответах 429/5xx запрос повторяется до трёх раз с
экспоненциальной паузой.

---

## Ограничения RuStore

- Загрузить сборку можно только с `versionCode` больше предыдущего.
- Отложенная публикация — не раньше чем через 24 часа и не позже чем через 60 дней.
- Процент раскатки можно только увеличивать.
- Архивировать можно только версии в статусах `READY_FOR_PUBLICATION` и `REJECTED_BY_MODERATOR`.
- Публиковать вручную можно только версию, прошедшую модерацию с типом `MANUAL`.

---

## Обновление с 1.0.x

Существующие вызовы `upload_to_ru_store` продолжают работать без изменений.
На что стоит обратить внимание:

- `publish_type: "DELAYED"` наконец работает — в 1.0.x `publish_datetime`
  не доходил до API, и вызов всегда падал;
- лимит changelog поднят с 500 до документированных API 5000 символов;
- минимальная версия Ruby — 3.2: дерево зависимостей fastlane требует её;
- HTTP-лог больше не печатается без запроса, включается через `RUSTORE_DEBUG`.

---

## Разработка

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Структура:

```
lib/fastlane/plugin/upload_to_ru_store/
├── actions/                 действия fastlane
└── helper/
    ├── upload_to_ru_store_helper.rb   фасад, сохраняющий обратную совместимость
    └── rustore/
        ├── signer.rb        загрузка ключа и подпись RSA-SHA512
        ├── client.rb        HTTP-транспорт, повторы, маскирование секретов
        ├── api.rb           методы RuStore API и валидация полей
        ├── options.rb       переиспользуемые ConfigItem
        └── errors.rb        типизированные ошибки
```

Сетевые вызовы в тестах замоканы через `webmock`, реальные соединения запрещены.

---

## Лицензия

MIT, см. [LICENSE](LICENSE).

## Ссылки

- [RuStore API: публикация приложений](https://www.rustore.ru/help/work-with-rustore-api/api-upload-publication-app)
- [Fastlane Plugins Guide](https://docs.fastlane.tools/plugins/create-plugin/)
