# ping-me-up

Быстрый Rust-инструмент мониторинга с уведомлениями в Telegram.

`pingmeup` — мониторинг CPU/RAM/Disk, уведомление при превышении порогов.

Заменяет старый `monitor-me.sh` (оставлен в репозитории для сравнения).

## Зачем Rust

| Метрика | Bash + curl/df/free/ps/find | Rust |
|---|---|---|
| Старт + работа | ~600 ms (форки утилит, sleep 1s) | ~10 ms + 500 ms CPU snapshot |
| RAM при работе | 5-15 MB на цепочку процессов | < 2 MB |
| Бинарь | — | ~2.3 MB stripped |
| Зависимости в рантайме | bash, curl, awk, free, df, ps, find | только glibc |

## Сборка

Нужен Rust toolchain (>= 1.74). Установка: <https://rustup.rs>.

```bash
./build.sh
# результат: target/release/pingmeup
```

Опционально полностью статичный musl-бинарь:

```bash
sudo apt-get install musl-tools
rustup target add x86_64-unknown-linux-musl
./build.sh --musl
# результат: target/x86_64-unknown-linux-musl/release/pingmeup
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

## Установка как системного сервиса

```bash
sudo install -Dm755 target/release/pingmeup /usr/local/bin/pingmeup
sudo install -d /etc/pingmeup
sudo install -m600 config.toml /etc/pingmeup/config.toml

sudo install -m644 systemd/pingmeup-monitor.service /etc/systemd/system/
sudo install -m644 systemd/pingmeup-monitor.timer   /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now pingmeup-monitor.timer

systemctl list-timers | grep pingmeup
journalctl -u pingmeup-monitor.service -f
```

Расписание по умолчанию: каждую минуту. Меняется в `pingmeup-monitor.timer`.

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

## Структура проекта

```
src/
  main.rs        # entry, argv handling
  config.rs      # TOML загрузка
  telegram.rs    # HTTP-клиент к Bot API (ureq + rustls)
  monitor.rs     # сборка отчёта по ресурсам
  procfs.rs      # /proc + statvfs парсеры
systemd/         # service + timer юниты
build.sh         # обёртка над cargo build
```

## Telegram setup

1. Создать бота через `@BotFather`.
2. Добавить бота в чат/группу/канал.
3. Получить `chat_id` целевого чата.
