# Unsplash Background Changer

Скрипт для установки случайных обоев с Unsplash. Работает на **Windows** (PowerShell) и **Linux** (bash), обе версии используют один и тот же `config.json`.

## Возможности

- 🖼️ Загрузка случайных изображений через Unsplash API (категория, размер, ориентация landscape)
- 🎨 Установка обоев: Windows, KDE Plasma, GNOME, Cinnamon, XFCE, Sway, а также feh/nitrogen для тайловых WM
- ⚙️ Консольный конфигуратор для Windows (`Setup.bat`)
- ⏰ Автозапуск: планировщик заданий Windows / autostart-файл сессии Linux
- 🧹 Автоочистка кэша скачанных изображений
- 📊 Логирование всех операций в `logs/unsplash-bg.log`

## Требования

| | Windows | Linux |
|---|---|---|
| Обязательно | Windows 10/11, PowerShell 5.1+ | `bash`, `curl`, `jq` (или `python3`) |
| Установка обоев | — (встроено) | KDE: `qdbus6` либо `plasma-apply-wallpaperimage`<br>GNOME / Cinnamon: `gsettings`<br>XFCE: `xfconf-query`<br>Sway: `swaymsg`<br>Прочие WM: `feh` или `nitrogen` |
| Общее | Доступ в интернет + Access Key Unsplash | |

Права администратора **не нужны** — обои и задача планировщика создаются в контексте текущего пользователя.

## Быстрый старт

### 1. Получение API ключа
1. Перейдите на [Unsplash Developers](https://unsplash.com/developers)
2. Создайте новое приложение
3. Скопируйте **Access Key**

### 2. Windows

```cmd
REM Интерактивная настройка: ключ, категория, разрешение, стиль, автозапуск
Setup.bat

REM Разовая смена обоев
Change-Wallpaper.bat
```

Оба файла при первом запуске создают `config.json` из `config.json.template`.

Если PowerShell блокирует запуск скриптов:
`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
(bat-файлы вызывают PowerShell с `-ExecutionPolicy Bypass`, поэтому обычно этого не требуется).

### 3. Linux

```bash
# Первый запуск создаёт config.json из шаблона
./change-wallpaper.sh

# Впишите Access Key
$EDITOR config.json      # unsplash.accessKey

# Смена обоев
./change-wallpaper.sh

# Автозапуск при входе в сессию
./install-autostart.sh
./install-autostart.sh --uninstall   # удалить
```

Конфигуратора для Linux нет — `config.json` правится вручную.

## Конфигурация

`config.json` (создаётся из `config.json.template`, в git не попадает — в нём лежит ключ).

```json
{
  "unsplash": {
    "accessKey": "ваш_api_ключ",
    "apiUrl": "https://api.unsplash.com",
    "defaultCategory": "nature",
    "defaultWidth": 1920,
    "defaultHeight": 1080
  },
  "download": {
    "tempPath": "$env:TEMP\\UnsplashBG",
    "keepImages": false,
    "maxCacheSize": 10
  },
  "wallpaper": {
    "style": "fill"
  },
  "autoChange": {
    "enabled": false,
    "intervalMinutes": 30
  },
  "taskScheduler": {
    "taskName": "UnsplashBackgroundChanger"
  },
  "logging": {
    "logFile": "logs\\unsplash-bg.log"
  }
}
```

| Ключ | Назначение |
|---|---|
| `unsplash.accessKey` | Access Key приложения Unsplash |
| `unsplash.apiUrl` | Базовый URL API |
| `unsplash.defaultCategory` | Поисковый запрос (`nature`, `city`, `minimal`, …) |
| `unsplash.defaultWidth` / `defaultHeight` | Размер изображения; передаётся в imgix-параметрах Unsplash (`fit=crop`) |
| `download.tempPath` | Куда скачивать. Windows-путь (`$env:TEMP\UnsplashBG`) на Linux игнорируется, там используется `${XDG_CACHE_HOME:-~/.cache}/UnsplashBG` |
| `download.keepImages` | `false` — хранить только текущие обои, `true` — историю до `maxCacheSize` файлов |
| `download.maxCacheSize` | Сколько файлов держать в кэше при `keepImages: true` |
| `wallpaper.style` | `fill`, `fit`, `stretch`, `center`, `tile` |
| `autoChange.enabled` / `intervalMinutes` | Периодическая смена: используется при создании задачи планировщика Windows |
| `taskScheduler.taskName` | Имя задачи в планировщике |
| `logging.logFile` | Файл лога; относительный путь считается от корня проекта |

### Стили обоев

| Стиль | Windows | KDE | GNOME / Cinnamon | feh |
|---|---|---|---|---|
| `fill` | Заполнить (обрезка) | Keep Proportions Crop | `zoom` | `--bg-fill` |
| `fit` | Вписать | Keep Proportions | `scaled` | `--bg-max` |
| `stretch` | Растянуть | Stretch | `stretched` | `--bg-scale` |
| `center` | По центру | Centered | `centered` | `--bg-center` |
| `tile` | Мозаика | Tiled | `wallpaper` | `--bg-tile` |

## Параметры Unsplash-BG.ps1

Всё, что не передано параметром, берётся из `config.json`.

```powershell
.\scripts\Unsplash-BG.ps1 [-Category <string>] [-Width <int>] [-Height <int>] [-Schedule]
```

| Параметр | Описание |
|---|---|
| `-Category` | Категория изображений |
| `-Width`, `-Height` | Размер изображения |
| `-Schedule` | Неинтерактивный режим: только запись в лог, без вывода в консоль (используется задачей планировщика) |

```powershell
# Базовое использование
.\scripts\Unsplash-BG.ps1

# С параметрами
.\scripts\Unsplash-BG.ps1 -Category "city" -Width 2560 -Height 1440
```

## Автозапуск

### Windows — планировщик заданий

1. `Setup.bat` → `7. Auto-startup Settings`
2. `1` — включить автосмену (`autoChange.enabled`)
3. `2` — задать интервал (`autoChange.intervalMinutes`)
4. `3` — создать задачу

Задача создаётся с двумя триггерами: при входе в систему и с заданным интервалом (если автосмена включена). После изменения интервала задачу нужно пересоздать (пункт 3). Удаление — пункт 4.

Вручную: `powershell -ExecutionPolicy Bypass -File scripts\Create-Task.ps1`

### Linux — вход в сессию

`./install-autostart.sh` создаёт `~/.config/autostart/unsplash-bg.desktop`, который запускает `change-wallpaper.sh` из текущего каталога проекта с задержкой 5 секунд (нужна, чтобы дождаться готовности plasmashell / шины сессии). Задержку можно изменить: `UNSPLASH_BG_DELAY=15 ./install-autostart.sh`.

Периодическая смена по интервалу на Linux **не реализована** — `autoChange.intervalMinutes` учитывается только планировщиком Windows. Если нужен интервал, добавьте systemd-таймер пользователя:

```ini
# ~/.config/systemd/user/unsplash-bg.service
[Unit]
Description=Unsplash Background Changer

[Service]
Type=oneshot
ExecStart=/полный/путь/к/проекту/change-wallpaper.sh
```

```ini
# ~/.config/systemd/user/unsplash-bg.timer
[Unit]
Description=Unsplash Background Changer timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=12h

[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now unsplash-bg.timer
```

## Структура проекта

```
├── Setup.bat                    # Windows: интерактивное меню настройки
├── Change-Wallpaper.bat         # Windows: разовая смена обоев
├── change-wallpaper.sh          # Linux: разовая смена обоев
├── install-autostart.sh         # Linux: автозапуск при входе в сессию
├── config.json.template         # Шаблон конфигурации
├── config.json                  # Рабочая конфигурация (в .gitignore)
├── logs/unsplash-bg.log         # Лог обеих версий
└── scripts/
    ├── Unsplash-BG.ps1          # Windows: основной скрипт
    ├── unsplash-bg.sh           # Linux: основной скрипт
    ├── Create-Task.ps1          # Создание задачи планировщика
    ├── Remove-Task.ps1          # Удаление задачи планировщика
    ├── Set-Config.ps1           # Запись значения в config.json (вызывается из Setup.bat)
    ├── Test-Connection.ps1      # Проверка API-ключа и сети
    └── Get-Resolution.ps1       # Определение разрешения экрана
```

## Решение проблем

| Симптом | Причина / решение |
|---|---|
| `ERROR: API key not configured` | Не заполнен `unsplash.accessKey` в `config.json` |
| `ERROR: Invalid API key (401)` | Ключ неверен или отозван; проверьте `Setup.bat` → `5. Test Connection` |
| `Rate limit exceeded (429)` | Лимит demo-приложения Unsplash — 50 запросов в час |
| Linux: `WARNING: Plasma detected but no working setter` | Установите `qdbus6` (пакет `qt6-tools`) или `plasma-apply-wallpaperimage` (`plasma-workspace`) |
| Linux: `No supported wallpaper setter found` | Окружение не распознано — установите `feh` |
| Linux: обои не меняются при входе в сессию | Увеличьте задержку: `UNSPLASH_BG_DELAY=15 ./install-autostart.sh` |
| Linux: `ERROR: neither jq nor python3 is installed` | Нужен любой из них: ими читаются и `config.json`, и ответ API |
| Windows: антивирус блокирует запуск | Добавьте папку проекта в исключения; запускайте `.bat`/`.ps1` (исполняемые файлы проект не собирает) |

Все запуски пишутся в `logs/unsplash-bg.log` — начинать диагностику стоит с него.

## Безопасность

`config.json` содержит Access Key и включён в `.gitignore`. Не коммитьте его; если ключ всё же попал в историю репозитория — отзовите его в [панели приложений Unsplash](https://unsplash.com/oauth/applications) и создайте новый.

## Лицензия

MIT License
