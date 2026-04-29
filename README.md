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

## Зависимости рантайма

- **Java JDK 17+** — Connect IQ SDK 9.x требует Java для запуска `monkeyc`.
  Установка: `winget install Microsoft.OpenJDK.21`
- **Connect IQ SDK 9.1.0+** через SDK Manager, device profile **Epix Gen 2**.

## Сборка (PowerShell)

В корне проекта лежат скрипты, которые сами находят SDK и Java:

```powershell
# debug сборка для epix2
.\build.ps1

# другая платформа
.\build.ps1 -Device fenix7

# release .iq для Connect IQ Store
.\build.ps1 -Release

# unit-тесты
.\build.ps1 -Test

# запуск симулятора и загрузка собранного prg
.\run.ps1
.\run.ps1 -Test
```

В VS Code: `Ctrl+Shift+P` → `Monkey C: Build for Device` → Epix Gen 2.

## Сборка (bash / git-bash)

```bash
export JAVA_HOME="/c/Program Files/Microsoft/jdk-21.0.10.7-hotspot"
export PATH="$JAVA_HOME/bin:$PATH"
SDK_BIN="/c/Users/n.khamzauly/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b/bin"

"$SDK_BIN/monkeyc.bat" -d epix2 -f monkey.jungle -o bin/namaz.prg -y developer_key
"$SDK_BIN/connectiq.bat" &
"$SDK_BIN/monkeydo.bat" bin/namaz.prg epix2
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
