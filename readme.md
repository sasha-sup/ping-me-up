# ping-me-up

Репозиторий содержит два bash-скрипта с уведомлениями в Telegram:

- `pinger.sh` — проверка доступности списка хостов по TCP-порту.
- `monitor-me.sh` — мониторинг CPU/RAM/Disk с уведомлением при превышении порогов.

## 1. Подготовка Telegram

1. Создайте бота через `@BotFather`.
2. Добавьте бота в чат/группу/канал для уведомлений.
3. Получите `CHAT_ID` целевого чата.

## 2. Конфигурация `.env`

Создайте файл `.env` в корне репозитория:

```bash
BOT_TOKEN="your_bot_token_here"
# или TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"

# Для pinger.sh
HOSTS=(
  "example1 192.168.1.1"
  "example2 192.168.1.2"
)

# Для monitor-me.sh (опционально)
CPU_THRESHOLD=85
RAM_THRESHOLD=85
DISK_THRESHOLD=90
TELEGRAM_TIMEOUT=8
MAX_MESSAGE_LENGTH=3500
LARGEST_FILES_LIMIT=5
DISK_SCAN_PATHS="/var /home /opt"
```

## 3. Запуск `pinger.sh`

```bash
./pinger.sh
```

Особенности:
- Порт по умолчанию: `22` (переопределяется через `PORT`).
- Таймаут проверки TCP: `CONNECT_TIMEOUT` (по умолчанию `2` сек).
- В Telegram отправляются только события недоступности хоста.

Пример с переменными окружения:

```bash
ENV_PATH=/path/to/.env PORT=443 CONNECT_TIMEOUT=1 ./pinger.sh
```

## 4. Запуск `monitor-me.sh`

```bash
ENV_PATH=/path/to/.env ./monitor-me.sh
```

Особенности:
- По умолчанию `ENV_PATH=/opt/monitor-me/.env`.
- Уведомление отправляется, только если хотя бы один порог превышен.
- Скрипт рассчитан на Linux (`/proc/stat`).

## 5. Cron

```bash
crontab -e
```

Примеры:

```cron
# Проверка хостов каждые 5 минут
*/5 * * * * cd /path/to/ping-me-up && ./pinger.sh

# Мониторинг ресурсов каждую минуту
* * * * * ENV_PATH=/path/to/ping-me-up/.env /path/to/ping-me-up/monitor-me.sh
```
