# Namaz — Garmin Connect IQ

Расчёт времени намаза для Garmin Epix Gen 2 по методике ҚМДБ (ДУМК).
Работает оффлайн, локально по GPS, уведомляет вибрацией.

> Текущий статус: **Этап 1 завершён** — каркас проекта.
> План разработки см. [CLAUDE.md](CLAUDE.md).

## Целевые устройства

- **Главное:** Garmin Epix Gen 2 (416×416 AMOLED, круглый)
- Совместимо: Fenix 7 / 7 Pro / 7X, Epix Pro, Forerunner 965

## Установка SDK

1. Скачайте **Connect IQ SDK Manager**: https://developer.garmin.com/connect-iq/sdk/
2. В SDK Manager установите:
   - Connect IQ SDK (последняя стабильная, ≥ 4.2.0)
   - Device profile: **Epix Gen 2**
3. Сгенерируйте developer key (один раз):

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
```

Положите `developer_key` в корень проекта (он в `.gitignore`).

4. В VS Code установите расширение **Monkey C** (Garmin).

## Сборка

```bash
# debug сборка для симулятора
monkeyc -d epix2 -f monkey.jungle -o bin/namaz.prg -y developer_key

# запуск симулятора и загрузка
connectiq
monkeydo bin/namaz.prg epix2

# release-сборка для Connect IQ Store
monkeyc -e -d epix2 -f monkey.jungle -o bin/namaz.iq -y developer_key -r
```

В VS Code: `Ctrl+Shift+P` → `Monkey C: Build for Device` → Epix Gen 2.

## Тесты

```bash
monkeyc -d epix2 -f monkey.jungle -o bin/namaz_test.prg -y developer_key --unit-test
monkeydo bin/namaz_test.prg epix2 -t
```

## Структура

```
source/        Monkey C исходники
  calc/        астрономия и расчёт намазов
  location/    GPS и кеш локации
  notify/      вибрация + scheduling
  ui/          темы и константы UI
  utils/       вспомогательные
resources/     строки, иконки, layouts, settings
tests/         unit-тесты
```

## Лицензия

TBD
