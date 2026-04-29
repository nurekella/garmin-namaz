# Namaz — Garmin Connect IQ приложение

> Задание для Claude Code. Реализовать приложение расчёта времени намаза для Garmin Epix Gen 2 согласно методике ҚМДБ (ДУМК).

---

## 1. Контекст

**Что строим:** нативное Connect IQ приложение для часов Garmin, которое:
- Рассчитывает время 5 ежедневных намазов локально (без интернета) по GPS-координатам
- Использует методику **ҚМДБ** (Қазақстан Мұсылмандарының Діни Басқармасы / ДУМК)
- Уведомляет вибрацией о наступлении времени намаза
- Работает на казахском, русском и английском языках

**Что НЕ делаем в v1.0:**
- Чтение Корана / суры / дуа
- Аудио-азан (только вибрация)
- Qibla-компас
- Социальные функции, статистика
- Поддержка часов без GPS

**Целевое устройство:** Garmin Epix Gen 2 (416×416 AMOLED, круглый экран, есть GPS, барометр, компас).

**Опциональная совместимость (если просто):** Fenix 7 / 7 Pro / 7X, Epix Pro, Forerunner 965.

---

## 2. Технологии

- **Язык:** Monkey C
- **SDK:** Connect IQ SDK (последняя стабильная, минимум 4.2.x)
- **API Level:** 4.2.0+
- **Минимальная версия Monkey C:** 4.0
- **Симулятор:** Connect IQ Simulator (поставляется с SDK)
- **Сборка:** `monkeyc` CLI или VS Code Monkey C extension
- **Тесты:** Monkey C unit testing framework (`Test.assertEqual`, `(:test)` annotation)

### Установка SDK (если ещё не установлен)

```bash
# 1. Скачать SDK Manager:
#    https://developer.garmin.com/connect-iq/sdk/
#
# 2. Через SDK Manager установить:
#    - Connect IQ SDK (последняя стабильная)
#    - Device profile: Epix Gen 2
#
# 3. Сгенерировать developer key:
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt

# 4. В VS Code установить расширение "Monkey C" (Garmin)
# 5. Connect IQ: New Project → выбрать Epix Gen 2 → Watch App
```

---

## 3. Структура проекта

```
namaz/
├── manifest.xml
├── monkey.jungle
├── developer_key                    # НЕ коммитить (gitignore)
├── README.md
├── source/
│   ├── NamazApp.mc                  # Application.AppBase, точка входа
│   ├── NamazView.mc                 # WatchUi.View, главный экран
│   ├── NamazDelegate.mc             # WatchUi.BehaviorDelegate, кнопки
│   ├── GlanceView.mc                # WatchUi.GlanceView (свайп с циферблата)
│   ├── BackgroundService.mc         # System.ServiceDelegate, фоновые уведомления
│   ├── calc/
│   │   ├── PrayerCalculator.mc      # основной модуль расчёта
│   │   ├── SolarMath.mc             # астрономия (склонение, equation of time, Julian Date)
│   │   ├── DumkMethod.mc            # параметры ҚМДБ
│   │   └── HijriDate.mc             # Григ → Хиджри (Umm al-Qura algorithm)
│   ├── location/
│   │   ├── LocationProvider.mc      # GPS + кэш в Storage
│   │   └── Cities.mc                # справочник городов Казахстана
│   ├── notify/
│   │   └── PrayerNotifier.mc        # Attention.vibrate() + scheduling
│   ├── ui/
│   │   ├── Theme.mc                 # цвета, шрифты, константы
│   │   └── PrayerNames.mc           # локализованные имена намазов
│   └── utils/
│       ├── TimeFormatter.mc
│       └── Storage.mc               # обёртка над Application.Storage
├── resources/
│   ├── strings/
│   │   ├── strings.xml              # default (en)
│   │   ├── strings-rus.xml
│   │   └── strings-kaz.xml
│   ├── settings/
│   │   ├── settings.xml             # для Garmin Connect Mobile
│   │   └── properties.xml
│   ├── menus/
│   │   └── settings_menu.xml        # настройки на часах
│   ├── layouts/
│   │   └── main_layout.xml
│   └── drawables/
│       ├── launcher_icon.png        # 40×40
│       └── drawables.xml
├── resources-round-416x416/         # Epix Gen 2 specific
│   └── (если нужны спец. ресурсы)
└── tests/
    ├── PrayerCalculatorTest.mc
    ├── SolarMathTest.mc
    └── HijriDateTest.mc
```

### `.gitignore`
```
bin/
*.prg
*.iq
developer_key
developer_key.pem
.DS_Store
```

---

## 4. Функциональные требования

### 4.1. Расчёт времени намаза

**Намазы (5 + 1 справочно):**
| ID | Казахский | Русский | English |
|---|---|---|---|
| FAJR | Таң | Фаджр | Fajr |
| SUNRISE | Шурук | Восход | Sunrise |
| DHUHR | Бесін | Зухр | Dhuhr |
| ASR | Екінді | Аср | Asr |
| MAGHRIB | Ақшам | Магриб | Maghrib |
| ISHA | Құптан | Иша | Isha |

### 4.2. Параметры ҚМДБ (по умолчанию)

```monkey-c
// source/calc/DumkMethod.mc
module DumkMethod {
    const FAJR_ANGLE     = 18.0;   // градусов ниже горизонта
    const ISHA_ANGLE     = 17.0;   // градусов ниже горизонта (близко к MWL)
    const MAGHRIB_OFFSET = 0;      // минут после заката
    const DHUHR_OFFSET   = 2;      // минут после астрономического полудня
    const ASR_FACTOR     = 2;      // Ханафи: тень = 2× высота объекта
    const HIGH_LAT_METHOD = :ANGLE_BASED;  // для широт > 48°
}
```

> **ВАЖНО:** Перед публикацией обязательно сверить расчёты с официальным календарём ҚМДБ (https://www.muftyat.kz/kk/prayer-times/) для Алматы, Астаны, Шымкента. Если расхождение > 1 минуты — подкрутить углы в `DumkMethod.mc`. Допустимо добавить per-prayer offset в settings (±9 минут).

### 4.3. Алгоритм расчёта (псевдокод)

```
1. Получить (lat, lon, date, timezone)
2. Julian Date  JD = julianDate(date)
3. T = (JD - 2451545.0) / 36525.0
4. Solar declination δ = SolarMath.declination(T)
5. Equation of Time EoT = SolarMath.equationOfTime(T)
6. Dhuhr = 12 + timezone - lon/15 - EoT/60 + DHUHR_OFFSET/60

7. Для каждого намаза с углом α:
   cos(H) = (sin(-α) - sin(lat)·sin(δ)) / (cos(lat)·cos(δ))
   T_offset = acos(H) / 15  (часов от полудня)

   Fajr     = Dhuhr - T(FAJR_ANGLE)
   Sunrise  = Dhuhr - T(0.833°)   // refraction
   Maghrib  = Dhuhr + T(0.833°)
   Isha     = Dhuhr + T(ISHA_ANGLE)

8. Asr (Ханафи): tan(α_asr) = ASR_FACTOR + tan(|lat - δ|)
   Asr = Dhuhr + T(α_asr)

9. Все времена → местное время (учесть DST через System.ClockTime)
```

### 4.4. Источник координат

**Приоритет:**
1. `Position.getInfo()` — текущий GPS
2. Кэш в `Application.Storage` (ключ `last_location`, TTL ~ 24ч или 5км)
3. Ручной выбор города из списка
4. Fallback: Алматы (43.2389, 76.8897)

### 4.5. Уведомления

```monkey-c
// Паттерн вибрации: 3 импульса × 500мс с интервалом 300мс
var vibeData = [
    new Attention.VibeProfile(100, 500),
    new Attention.VibeProfile(0,   300),
    new Attention.VibeProfile(100, 500),
    new Attention.VibeProfile(0,   300),
    new Attention.VibeProfile(100, 500)
];
Attention.vibrate(vibeData);
```

**Расписание:** через `Background.registerForTemporalEvent()` — Garmin запускает фоновый сервис в указанное время.

**Опционально:** предуведомление за 10 минут (toggle в settings, по умолчанию **off**).

### 4.6. Экраны (см. прототип)

**Цвета (true black AMOLED):**
```monkey-c
module Theme {
    const COLOR_BG          = 0x000000;  // true black
    const COLOR_TEXT        = 0xF5F0E8;  // тёплый белый
    const COLOR_TEXT_DIM    = 0x6E6860;  // приглушённый
    const COLOR_TEXT_MUTED  = 0x3D3833;  // прошедшие намазы
    const COLOR_ACCENT      = 0xD4A574;  // бронзовый
    const COLOR_ACCENT_DIM  = 0x8A6D4A;
}
```

**Шрифты:** системные Garmin (`FONT_LARGE`, `FONT_MEDIUM`, `FONT_TINY`, `FONT_NUMBER_HOT`, `FONT_NUMBER_THAI_HOT`) — кастомные .fnt не используем для v1.0 чтобы уложиться в memory budget.

**Главный экран (NamazView):**
- Сверху: дата (грег. + хиджри)
- Центр: следующий намаз (название + countdown HH:MM:SS)
- Снизу: список 5 намазов (2 колонки), активный = акцент, прошедшие = muted

**Glance View:**
- Иконка солнца/полумесяца
- "КЕЛЕСІ" / "СЛЕДУЮЩИЙ" / "NEXT"
- Название намаза (большое)
- Время + countdown

**Notification View** (открывается по тапу на уведомление):
- Пульсирующая иконка вибрации
- "НАМАЗ ВАҚЫТЫ"
- Название + время

**Settings (на часах через Menu2):**
- Метод (ҚМДБ / MWL / ISNA / Egyptian / Umm al-Qura / Karachi / Diyanet)
- Аср (Ханафи / Стандарт)
- Тіл / Язык / Language
- Алдын-ала ескерту (Off / 5 / 10 / 15 мин)
- Қала (автоматически / список)
- Per-prayer offset (-9..+9 мин для каждого намаза)

### 4.7. Локализация

**Структура `resources/strings/strings-kaz.xml`:**
```xml
<strings>
    <string id="AppName">Namaz</string>
    <string id="NextPrayer">КЕЛЕСІ НАМАЗ</string>
    <string id="PrayerFajr">Таң</string>
    <string id="PrayerSunrise">Шурук</string>
    <string id="PrayerDhuhr">Бесін</string>
    <string id="PrayerAsr">Екінді</string>
    <string id="PrayerMaghrib">Ақшам</string>
    <string id="PrayerIsha">Құптан</string>
    <string id="PrayerTime">Намаз уақыты</string>
    <string id="GpsSearching">GPS іздеу</string>
    <string id="SettingsTitle">Баптаулар</string>
    <string id="SettingMethod">Әдіс</string>
    <string id="SettingAsr">Аср</string>
    <string id="SettingLanguage">Тіл</string>
    <string id="SettingPreAlert">Алдын-ала</string>
    <string id="SettingCity">Қала</string>
    <string id="MinutesShort">мин</string>
    <string id="HoursShort">сағ</string>
    <string id="LeftSuffix">қалды</string>
    <string id="MonthApr">Сәу</string>
    <!-- остальные месяцы -->
</strings>
```

Аналогично `strings-rus.xml` (Фаджр/Зухр/Аср/Магриб/Иша) и `strings.xml` (Fajr/Dhuhr/Asr/Maghrib/Isha — английский по умолчанию).

---

## 5. Спецификация модулей

### 5.1. `source/calc/SolarMath.mc`

```monkey-c
module SolarMath {
    // Все углы в градусах, конвертация внутри функций
    function julianDate(year, month, day);          // → Double
    function declination(jd);                       // → Double (deg)
    function equationOfTime(jd);                    // → Double (minutes)
    function hourAngle(latitude, declination, angle); // → Double (hours)
    function asrAngle(latitude, declination, factor); // → Double (deg)

    // Helpers
    function deg2rad(deg);
    function rad2deg(rad);
    function fixHour(hour);  // нормализация в [0, 24)
}
```

### 5.2. `source/calc/PrayerCalculator.mc`

```monkey-c
class PrayerCalculator {
    var _method;       // DumkMethod / MwlMethod / etc.
    var _asrFactor;    // 1 = Standard, 2 = Hanafi
    var _offsets;      // dictionary {fajr: 0, dhuhr: 0, ...}

    function initialize(method, asrFactor, offsets);

    // Основной API
    function calculate(latitude, longitude, date, timezoneOffset);
    // → Dictionary { :fajr => Moment, :sunrise => Moment, ...

    function getNextPrayer(prayerTimes, currentMoment);
    // → { :name => :dhuhr, :time => Moment, :secondsUntil => 2538 }

    // Internal
    private function computeTime(angle, dhuhr, lat, decl, direction);
    private function applyHighLatitudeAdjustment(time, ...);
}
```

### 5.3. `source/calc/HijriDate.mc`

Использовать **Umm al-Qura algorithm** (табличный, точный для дат 1300-1500 AH). Простая реализация через массив длин месяцев. См. https://www.staff.science.uu.nl/~gent0113/islam/ummalqura.htm

```monkey-c
module HijriDate {
    function fromGregorian(year, month, day);  // → {year, month, day}
    function monthNameKaz(monthNum);  // → "Шаууал" etc.
    function monthNameRus(monthNum);
    function monthNameEng(monthNum);
}
```

### 5.4. `source/location/LocationProvider.mc`

```monkey-c
class LocationProvider {
    function initialize();
    function getCurrentLocation();  // → {lat, lon, accuracy, timestamp}
    function getCachedLocation();
    function setManualCity(cityId);
    function isLocationStale(ttl);
}
```

### 5.5. `source/location/Cities.mc`

Справочник городов Казахстана:
```monkey-c
module Cities {
    const KAZAKHSTAN = [
        { :id => "almaty",      :name_kk => "Алматы",       :lat => 43.2389, :lon => 76.8897, :tz => 5 },
        { :id => "astana",      :name_kk => "Астана",       :lat => 51.1694, :lon => 71.4491, :tz => 5 },
        { :id => "shymkent",    :name_kk => "Шымкент",      :lat => 42.3417, :lon => 69.5901, :tz => 5 },
        { :id => "karaganda",   :name_kk => "Қарағанды",    :lat => 49.8047, :lon => 73.1094, :tz => 5 },
        { :id => "aktobe",      :name_kk => "Ақтөбе",       :lat => 50.2839, :lon => 57.1670, :tz => 5 },
        { :id => "taraz",       :name_kk => "Тараз",        :lat => 42.9000, :lon => 71.3667, :tz => 5 },
        { :id => "pavlodar",    :name_kk => "Павлодар",     :lat => 52.2873, :lon => 76.9674, :tz => 5 },
        { :id => "ust",         :name_kk => "Өскемен",      :lat => 49.9483, :lon => 82.6275, :tz => 5 },
        { :id => "semey",       :name_kk => "Семей",        :lat => 50.4111, :lon => 80.2275, :tz => 5 },
        { :id => "atyrau",      :name_kk => "Атырау",       :lat => 47.0945, :lon => 51.9238, :tz => 5 },
        { :id => "kostanay",    :name_kk => "Қостанай",     :lat => 53.2198, :lon => 63.6354, :tz => 5 },
        { :id => "kyzylorda",   :name_kk => "Қызылорда",    :lat => 44.8479, :lon => 65.4823, :tz => 5 },
        { :id => "uralsk",      :name_kk => "Орал",         :lat => 51.2333, :lon => 51.3667, :tz => 5 },
        { :id => "petropavl",   :name_kk => "Петропавл",    :lat => 54.8753, :lon => 69.1497, :tz => 5 },
        { :id => "aktau",       :name_kk => "Ақтау",        :lat => 43.6500, :lon => 51.1500, :tz => 5 },
        { :id => "turkestan",   :name_kk => "Түркістан",    :lat => 43.2972, :lon => 68.2517, :tz => 5 }
    ];
}
```

### 5.6. `source/notify/PrayerNotifier.mc`

```monkey-c
class PrayerNotifier {
    function scheduleNextPrayer(prayerTimes);     // вызывает Background.registerForTemporalEvent
    function onPrayerTime(prayerName);            // в фоновом сервисе → vibrate
    function getVibePattern();                    // → Array<VibeProfile>
}
```

### 5.7. `source/BackgroundService.mc`

```monkey-c
class BackgroundService extends System.ServiceDelegate {
    function onTemporalEvent() {
        // 1. Загрузить inferred prayer time из Storage
        // 2. Вызвать PrayerNotifier.onPrayerTime()
        // 3. Запланировать следующий
        Background.exit(null);
    }
}
```

---

## 6. План реализации (этапы)

Делать **строго по порядку**, после каждого этапа коммит и проверка в симуляторе.

### Этап 1: Каркас проекта
- [ ] Создать структуру папок
- [ ] `manifest.xml` с указанием Epix Gen 2, permissions: `Positioning`, `Background`, `UserProfile`
- [ ] `monkey.jungle` с jungle entry для `epix2`
- [ ] Минимальный `NamazApp.mc` + `NamazView.mc` показывает "Namaz"
- [ ] Сборка проходит, симулятор запускается
- [ ] **Commit:** `chore: scaffold project`

### Этап 2: Астрономические расчёты
- [ ] `SolarMath.mc` — все функции
- [ ] `tests/SolarMathTest.mc` — проверить Julian Date, declination, EoT для известных дат (1 янв 2000, 21 июн 2024 — есть эталонные значения в NOAA)
- [ ] **Commit:** `feat(calc): solar math primitives`

### Этап 3: Калькулятор намазов
- [ ] `DumkMethod.mc`
- [ ] `PrayerCalculator.mc`
- [ ] `tests/PrayerCalculatorTest.mc` — тест-кейсы для Алматы (см. §10)
- [ ] Сверка с muftyat.kz: расхождение должно быть ≤ 1 мин
- [ ] **Commit:** `feat(calc): prayer time calculator with DUMK method`

### Этап 4: Локация
- [ ] `LocationProvider.mc` с GPS + Storage кэш
- [ ] `Cities.mc` справочник
- [ ] Fallback на последнюю локацию или Алматы
- [ ] **Commit:** `feat(location): GPS provider with cache`

### Этап 5: Главный UI
- [ ] `Theme.mc` с цветами и шрифтами
- [ ] `NamazView.mc` рисует список намазов согласно прототипу
- [ ] `NamazDelegate.mc` обрабатывает кнопки (Up/Down/Select/Back/Menu)
- [ ] Обновление времени каждую секунду через `WatchUi.requestUpdate()` в `onUpdate()`
- [ ] **Commit:** `feat(ui): main view with prayer list`

### Этап 6: Glance View
- [ ] `GlanceView.mc`
- [ ] Регистрация в manifest: `<iq:application ... entry="NamazApp" type="watch-app">` + `<iq:permissions>` + glance
- [ ] **Commit:** `feat(ui): glance view`

### Этап 7: Уведомления
- [ ] `PrayerNotifier.mc`
- [ ] `BackgroundService.mc`
- [ ] Регистрация temporal event на следующий намаз
- [ ] Тест на симуляторе через "Trigger Background Event"
- [ ] **Commit:** `feat(notify): vibration on prayer time`

### Этап 8: Настройки
- [ ] `resources/settings/settings.xml` для Garmin Connect Mobile
- [ ] `resources/menus/settings_menu.xml` для on-watch settings (Menu2)
- [ ] `properties.xml` со значениями по умолчанию
- [ ] **Commit:** `feat(settings): user preferences`

### Этап 9: Локализация
- [ ] `strings.xml`, `strings-rus.xml`, `strings-kaz.xml`
- [ ] Использование `Rez.Strings.*` во всём UI
- [ ] **Commit:** `feat(i18n): KK/RU/EN localization`

### Этап 10: Хиджри
- [ ] `HijriDate.mc` с Umm al-Qura algorithm
- [ ] `tests/HijriDateTest.mc` — проверить известные даты
- [ ] Отображение на главном экране
- [ ] **Commit:** `feat(calc): hijri date conversion`

### Этап 11: Полировка
- [ ] Проверка memory usage (`Compiler error if exceed`)
- [ ] Тестирование на батарее (запустить на 24 часа)
- [ ] Иконки (40×40 launcher_icon.png)
- [ ] README на русском с инструкцией установки
- [ ] **Commit:** `chore: polish and docs`

---

## 7. Тестовые данные (для верификации)

### Алматы, 29 апреля 2026 (UTC+5)
**Координаты:** 43.2389°N, 76.8897°E

Эталонные времена (получить с muftyat.kz и зашить в тест):
```
Фаджр:     ~04:32
Восход:    ~06:14
Зухр:      ~13:05
Аср:       ~17:48  (Ханафи)
Магриб:    ~20:12
Иша:       ~21:54
```

> ⚠️ Точные значения нужно взять с официального сайта на день верификации. Тест должен сверять расчёт с этими значениями ±1 мин.

### Тест-кейс на код:

```monkey-c
(:test)
function testAlmatyApril29(logger) {
    var calc = new PrayerCalculator(:DUMK, 2, {});  // Hanafi
    var times = calc.calculate(43.2389, 76.8897,
                                {:year=>2026, :month=>4, :day=>29}, 5);

    Test.assertEqualMessage(formatTime(times[:fajr]),    "04:32",
        "Fajr time mismatch for Almaty 2026-04-29");
    Test.assertEqualMessage(formatTime(times[:dhuhr]),   "13:05",
        "Dhuhr time mismatch");
    Test.assertEqualMessage(formatTime(times[:asr]),     "17:48",
        "Asr (Hanafi) time mismatch");
    Test.assertEqualMessage(formatTime(times[:maghrib]), "20:12",
        "Maghrib time mismatch");
    Test.assertEqualMessage(formatTime(times[:isha]),    "21:54",
        "Isha time mismatch");
    return true;
}
```

Аналогичные тесты для:
- **Астана** (51.1694, 71.4491) — северная точка, проверка high-latitude
- **Шымкент** (42.3417, 69.5901) — южная точка
- **21 июня** (летнее солнцестояние) — крайний случай
- **21 декабря** (зимнее солнцестояние) — крайний случай

---

## 8. manifest.xml (стартовый шаблон)

```xml
<?xml version="1.0"?>
<iq:manifest version="3" xmlns:iq="http://www.garmin.com/xml/connectiq">
    <iq:application
        entry="NamazApp"
        id="GENERATE_NEW_UUID"
        launcherIcon="@Drawables.LauncherIcon"
        minSdkVersion="4.2.0"
        name="@Strings.AppName"
        type="watch-app"
        version="1.0.0">

        <iq:products>
            <iq:product id="epix2"/>
            <!-- опционально: -->
            <iq:product id="fenix7"/>
            <iq:product id="fenix7pro"/>
            <iq:product id="epix2pro47mm"/>
            <iq:product id="fr965"/>
        </iq:products>

        <iq:permissions>
            <iq:uses-permission id="Positioning"/>
            <iq:uses-permission id="Background"/>
            <iq:uses-permission id="UserProfile"/>
        </iq:permissions>

        <iq:languages>
            <iq:language>eng</iq:language>
            <iq:language>rus</iq:language>
            <iq:language>kaz</iq:language>
        </iq:languages>

        <iq:barrels/>
    </iq:application>
</iq:manifest>
```

UUID сгенерировать через `monkeyc --uuid` или `uuidgen`.

---

## 9. Команды сборки и отладки

```bash
# Сборка для симулятора
monkeyc -d epix2 -f monkey.jungle -o bin/namaz.prg -y developer_key

# Запуск симулятора
connectiq

# Загрузка в симулятор
monkeydo bin/namaz.prg epix2

# Запуск тестов
monkeyc -d epix2 -f monkey.jungle -o bin/namaz_test.prg -y developer_key --unit-test
monkeydo bin/namaz_test.prg epix2 -t

# Сборка release (.iq для Connect IQ Store)
monkeyc -e -d epix2 -f monkey.jungle -o bin/namaz.iq -y developer_key -r
```

В VS Code: `Ctrl+Shift+P` → `Monkey C: Build for Device` → выбрать Epix Gen 2.

---

## 10. Критерии приёмки

- [ ] Время намазов для Алматы / Астаны / Шымкента совпадает с muftyat.kz ±1 мин круглый год
- [ ] Все 5 намазов показываются на главном экране
- [ ] Активный намаз выделен бронзовым цветом, прошедшие — приглушены
- [ ] Countdown до следующего намаза обновляется каждую секунду
- [ ] Glance View работает свайпом с циферблата
- [ ] Вибрация (3 импульса) срабатывает в точное время намаза в фоне
- [ ] Приложение работает без интернета после первого получения GPS
- [ ] Переключение языков KK / RU / EN работает корректно
- [ ] Все юнит-тесты зелёные (`monkeydo ... -t`)
- [ ] Memory usage в симуляторе < 32 KB peak (Epix Gen 2 watch-app limit)
- [ ] Нет крашей при навигации Up/Down/Select/Back/Menu
- [ ] Расход батареи в фоне < 2% / сутки

---

## 11. Полезные ссылки

- Connect IQ Programmer's Guide: https://developer.garmin.com/connect-iq/programmers-guide/
- API Reference: https://developer.garmin.com/connect-iq/api-docs/
- Calendar muftyat.kz: https://www.muftyat.kz/kk/prayer-times/
- Prayer time algorithms: http://praytimes.org/calculation/
- Umm al-Qura Hijri tables: https://www.staff.science.uu.nl/~gent0113/islam/ummalqura.htm

---

## 12. Замечания для Claude Code

1. **Не предполагай** значения углов ҚМДБ — после написания калькулятора обязательно сверь с muftyat.kz и при расхождении подкрути константы в `DumkMethod.mc`. Если расхождение систематическое — может быть нужен per-prayer offset, добавь его в settings.

2. **Storage API** в Connect IQ имеет лимит 8 KB на ключ для watch-app. Не пихай туда сырые объекты — сериализуй в Dictionary с примитивами.

3. **Не используй** в Background сервисе тяжёлый код — у него лимит 30 секунд и ~32 KB памяти. Расчёт должен быть быстрый.

4. **Тестируй на симуляторе с разными датами** через `Settings → Time & Date` в симуляторе. Особенно проверь даты вблизи DST (хотя в Казахстане DST нет, но в других регионах может быть).

5. **Проверь поведение** при отказе GPS (в симуляторе: `Position → No Fix`) — должен показаться экран ручного выбора города или fallback.

6. **Шрифт казахского/русского** — в системных шрифтах Garmin кириллица есть, но не все символы. Проверь Ұ/Қ/Ң/Ғ/Ө/Ә/І/Һ — если каких-то нет, придётся подключить кастомный .fnt (увеличит размер). Сначала проверь стандартные.

7. После каждого этапа делай **коммит с конвенциональным сообщением** (`feat:`, `fix:`, `chore:`, `test:`).

8. Если возникает архитектурный вопрос (например, как организовать кеш или какой выбрать подход для high-latitude) — предложи 2-3 варианта с плюсами/минусами и выбери дефолтный, не блокируйся.

9. **Pre-commit:** перед каждым коммитом запускай тесты и сборку, убедись что всё зелёное.

---

**Готов начать с Этапа 1.**