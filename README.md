# Namaz — Garmin Connect IQ

Расчёт времени намаза для Garmin Epix Gen 2 по методике **ҚМДБ (ДУМК)**.
Работает оффлайн, локально по GPS, уведомляет вибрацией.

Языки: **қазақша / русский / english** (выбирается по системному языку часов).

## Возможности (v1.0)

- 5 ежедневных намазов + восход (Таң, Күн, Бесін, Екінді, Ақшам, Құптан)
- Расчёт по координатам GPS — без интернета после первого фикса
- Хиджри-дата на главном экране (табличный Кувейтский алгоритм)
- Glance-виджет со следующим намазом и обратным отсчётом
- Вибрация в момент намаза + опциональное предуведомление (5/10/15 мин)
- Ханафи / стандартный мазхаб для Аср (по умолчанию Ханафи)
- Per-prayer offset ±9 мин в настройках (на часах через Menu2 и в Connect Mobile)
- Ручной выбор города из 16 областных центров Казахстана + Auto (GPS)
- True-black AMOLED тема, заточена под Epix Gen 2

## Точность

Калибровано против [muftyat.kz](https://www.muftyat.kz/kk/prayer-times/):
расхождение ≤ 1.6 мин для Алматы, ≤ 1.1 мин для Шымкента круглый год.
Метод: углы Fajr/Isha 15.5°, Sunrise 1.0°, плюс per-prayer offset.

## Целевые устройства

- **Главное:** Garmin Epix Gen 2 (416×416 AMOLED, круглый)
- Совместимо: Fenix 7 / 7 Pro / 7X, Epix Pro, Forerunner 965

## Установка SDK (для разработки)

1. Скачайте **Connect IQ SDK Manager**: https://developer.garmin.com/connect-iq/sdk/
2. В SDK Manager установите Connect IQ SDK ≥ 9.1.0 и device profile **Epix Gen 2**.
3. Установите Java JDK 21:
   ```powershell
   winget install Microsoft.OpenJDK.21
   ```
4. Сгенерируйте developer key (один раз):
   ```bash
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
   ```
   Положите `developer_key` в корень проекта (он в `.gitignore`).
5. В VS Code установите расширение **Monkey C** (Garmin).

## Сборка (PowerShell)

```powershell
.\build.ps1                  # debug для epix2
.\build.ps1 -Device fenix7   # другая платформа
.\build.ps1 -Release         # release .iq для Connect IQ Store
.\build.ps1 -Test            # unit-тесты

.\run.ps1                    # запустить симулятор и загрузить prg
.\run.ps1 -Test              # запустить тесты в симуляторе
```

## Установка на часы

1. Соберите release: `.\build.ps1 -Release` → получаете `bin\namaz.iq`.
2. Подключите часы по USB, скопируйте `namaz.prg` (debug) в `GARMIN/APPS/`.
3. Для публикации в Connect IQ Store загружайте `.iq` через
   https://apps.garmin.com/.

## Настройки

На часах: долгое нажатие центральной кнопки → **Settings**.
Через Connect Mobile: Garmin Connect → My Watch → Connect IQ Apps → Namaz.

| Параметр       | Описание                                     |
|----------------|----------------------------------------------|
| Аср            | Стандарт / Ханафи                            |
| Қала           | Auto (GPS) / 16 городов Казахстана           |
| Алдын-ала      | Off / 5 / 10 / 15 мин до намаза              |
| Offset (×6)    | ±9 мин для каждого намаза индивидуально      |

## Структура

```
source/
  calc/        астрономия и расчёт намазов (DumkMethod, SolarMath, PrayerCalculator, HijriDate)
  location/    GPS и кеш локации (LocationProvider, Cities)
  notify/      вибрация + scheduling (PrayerNotifier)
  ui/          темы и локализованные имена (Theme, PrayerNames)
  utils/       вспомогательные (TimeFormatter, Storage)
  NamazApp.mc, NamazView.mc, NamazDelegate.mc, GlanceView.mc, BackgroundService.mc
resources/     strings (en/ru/kk), settings, menus, drawables
tests/         87 unit-тестов
```

## Известные ограничения

- Glance и фоновый сервис показывают строки на английском (Rez недоступен в их
  бинарниках) — локализация glance запланирована на v1.1.
- Хиджри-дата может отличаться от Umm al-Qura на ±1 день в граничные дни месяца.
- Высокие широты (> 48°): используется angle-based fallback.

## Лицензия

TBD
