# ping-me-up

Быстрый Rust-инструмент мониторинга с уведомлениями в Telegram.

`pingmeup` — мониторинг CPU/RAM/Disk, уведомление при превышении порогов.

Старая bash-версия лежит в `legacy/` и помечена как deprecated.

## Зачем Rust

| Метрика | Bash + curl/df/free/ps/find | Rust |
|---|---|---|
| Старт + работа | ~600 ms (форки утилит, sleep 0.5s) | ~10 ms + 500 ms CPU snapshot |
| RAM при работе | 5-15 MB на цепочку процессов | < 2 MB |
| Бинарь | — | ~2.3 MB stripped |
| Зависимости в рантайме | bash, curl, awk, free, df, ps, find | только glibc (или 0, если musl-static) |

Бенч (hyperfine, 15 прогонов): 3.14× быстрее на полном цикле с обходом диска, 8-20× меньше CPU-времени. Подробности — в commit history.

## Установка

### A. Скачать готовый бинарь из GitHub Releases

Для каждого релиза `vX.Y.Z` публикуются архивы для:

- `x86_64-unknown-linux-gnu` (стандартный Linux x86_64)
- `x86_64-unknown-linux-musl` (полностью статический x86_64)
- `aarch64-unknown-linux-gnu` (ARM64 Linux, например AWS Graviton)
- `aarch64-unknown-linux-musl` (ARM64 статический)

```bash
# пример
TAG=v0.1.0
TARGET=x86_64-unknown-linux-musl
curl -fsSL -o pingmeup.tar.gz \
    "https://github.com/<user>/<repo>/releases/download/${TAG}/pingmeup-${TAG}-${TARGET}.tar.gz"
tar xzf pingmeup.tar.gz
sudo install -Dm755 pingmeup /usr/local/bin/pingmeup
```

Также для каждой ветки `main` workflow `ci` сохраняет artifact `pingmeup-x86_64-linux-musl` (на 30 дней) — доступен из вкладки Actions.

### B. Собрать самому

Нужен Rust toolchain (см. `rust-toolchain.toml`). Установка: <https://rustup.rs>.

```bash
make build              # glibc dynamic, target/release/pingmeup
make musl               # static, target/x86_64-unknown-linux-musl/release/pingmeup
make install            # установить в /usr/local/bin + создать /etc/pingmeup/config.toml из шаблона
make systemd-install    # + установить и включить timer
make help               # список целей
```

## Конфиг

`pingmeup` ищет конфиг в таком порядке:

1. `$PINGMEUP_CONFIG` (переменная окружения).
2. `./config.toml` (текущая директория).
3. `/etc/pingmeup/config.toml`.

Шаблон — `config.example.toml`.

```toml
[telegram]
bot_token = "your_bot_token_here"
chat_id = "your_chat_id_here"
timeout_secs = 8

[monitor]
cpu_threshold = 85.0
ram_threshold = 85.0
disk_threshold = 90.0
disk_scan_paths = ["/var", "/home", "/opt"]
largest_files_limit = 5
max_message_length = 3500
top_processes = 3
```

Хранить с правами `chmod 600 config.toml` — содержит токен бота.

## Запуск

```bash
pingmeup
pingmeup --help
pingmeup --version
```

Override конфига:

```bash
PINGMEUP_CONFIG=/path/to/config.toml pingmeup
```

## systemd

```bash
make systemd-install
systemctl list-timers | grep pingmeup
journalctl -u pingmeup-monitor.service -f
```

Расписание по умолчанию: каждую минуту. Меняется в `systemd/pingmeup-monitor.timer`.

Снять: `make systemd-uninstall`.

## Альтернатива: cron

```cron
* * * * * PINGMEUP_CONFIG=/etc/pingmeup/config.toml /usr/local/bin/pingmeup
```

## Что делает программа

- CPU: две выборки `/proc/stat` с интервалом 500 ms.
- RAM: `MemTotal` и `MemAvailable` из `/proc/meminfo`.
- Disk: `statvfs("/")`.
- Top processes: чтение `/proc/[pid]/stat`, расчёт %CPU/%MEM как у `ps`.
- Largest files: рекурсивный обход `disk_scan_paths` с `-xdev`.
- Сообщение в Telegram отправляется только если хотя бы один порог превышен.

## CI/CD

- `.github/workflows/ci.yml` — на push/PR в `main`: `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test`, сборка musl-бинаря, upload artifact на 30 дней.
- `.github/workflows/release.yml` — на тег `v*`: cross-сборка под четыре цели и публикация в GitHub Release.

Локально те же проверки: `make fmt lint test`.

Чтобы выпустить релиз:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Структура проекта

```
src/
  main.rs        # entry, argv handling
  config.rs      # TOML загрузка
  telegram.rs    # HTTP-клиент к Bot API (ureq + rustls)
  monitor.rs     # сборка отчёта по ресурсам
  procfs.rs      # /proc + statvfs парсеры
systemd/         # service + timer юниты
.github/workflows/
  ci.yml         # lint/test/build на push
  release.yml    # cross-build + GitHub Release на тег
legacy/          # deprecated bash-версия (только для истории)
Makefile         # обёртка над cargo + install + systemd
```

## Telegram setup

1. Создать бота через `@BotFather`.
2. Добавить бота в чат/группу/канал.
3. Получить `chat_id` целевого чата.
