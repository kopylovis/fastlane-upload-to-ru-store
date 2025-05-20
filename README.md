# upload_to_ru_store

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-upload_to_ru_store)

**Fastlane-плагин для автоматической публикации Android-приложений (AAB/APK) в RuStore.**

За основу взять плагин от Vladislav Onishchenko: https://github.com/stfbee/fastlane-plugin-rustore

## Возможности

- Аутентификация через RSA-SHA512 и получение JWE-токена RuStore API
- Автоматическая очистка всех незавершённых черновиков (draft) перед созданием новой версии
- Создание драфта с указанием типа публикации и текста «Что нового»
- Загрузка AAB или APK (GMS и/или HMS) в один или два шага
- Фиксация (commit) драфта и отправка на модерацию

## Установка

В каталоге с вашим Fastfile выполните:

```bash
fastlane add_plugin upload_to_ru_store
```

## Пример использования

```ruby
lane :publish_to_rustore do
  upload_to_ru_store(
    package_name: "com.example.app",
    key_id: ENV["RUSTORE_KEY_ID"],
    private_key: ENV["RUSTORE_PRIVATE_KEY"],
    publish_type: "INSTANTLY", # MANUAL, DELAYED или INSTANTLY (по умолчанию INSTANTLY)
    changelog_path: "metadata/android/ru-RU/changelog.txt", # опционально, макс. 500 символов
    aab: "app/build/outputs/bundle/release/app-release.aab", # если указан, зальётся только AAB
    gms_apk: "app/build/outputs/apk/release/app-release.apk", # путь к Google-APK (если не указан AAB)
    hms_apk: "app-huawei-release.apk" # путь к Huawei-APK (опционально)
  )
end
```

**Плагин автоматически:**

1. Получит JWE-токен RuStore
2. Удалит все существующие черновики приложения
3. Создаст новый драфт
4. Загрузит указанные сборки (AAB и/или APK)
5. Закоммитит драфт и отправит на модерацию

## Опции

| Параметр           | Описание                                                                       | Обязательный                           | Формат   |
|--------------------|--------------------------------------------------------------------------------|----------------------------------------|----------|
| `package_name`     | Уникальный идентификатор пакета (например, `com.example.app`)                  | да                                     | `String` |
| `key_id`           | Идентификатор RSA-ключа в консоли RuStore                                      | да                                     | `String` |
| `private_key`      | PEM-строка RSA-приватного ключа                                                | да                                     | `String` |
| `publish_type`     | Тип публикации: `MANUAL`, `DELAYED` или `INSTANTLY` (по умолчанию `INSTANTLY`) | нет                                    | `String` |
| `publish_datetime` | Дата и время для отложенной публикации, ISO8601                                | да, только если publish_type = DELAYED | `String` |
| `changelog_path`   | Путь к `.txt`-файлу с описанием «Что нового?» (макс. 500 символов)             | нет                                    | `String` |
| `aab`              | Путь к Android App Bundle (`.aab`). Если указан, APK не загружается            | нет                                    | `String` |
| `gms_apk`          | Путь к APK с Google Mobile Services. Используется, если не указан `aab`        | нет                                    | `String` |
| `hms_apk`          | Путь к APK с Huawei Mobile Services                                            | нет                                    | `String` |

## Требования

- Ruby >= 2.6
- Fastlane >= 2.214.0

## Лицензия

MIT. Смотрите [LICENSE](LICENSE)

## Полезные ссылки

- [Документация RuStore API](https://help.rustore.ru/rustore/for_developers/work_with_RuStore_API)
- [Fastlane Plugins Guide](https://docs.fastlane.tools/plugins/create-plugin/)
