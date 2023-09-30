# Host Availability with Telegram Notifications

This script monitors the availability of specified hosts and sends notifications to Telegram if a host becomes unavailable.

## Instructions

### 1. Create a Telegram Bot

1. Start a chat with `@BotFather` on Telegram.
2. Use the `/newbot` command to create a new bot.
3. Follow the instructions to obtain your bot's token.

### 2. Create a Telegram Group or Channel

1. Create a group or channel on Telegram where availability notifications will be sent.
2. Add the created bot to this group or channel.

### 3. Configure the .env File

```sh
# Create a .env file in the same directory
TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"

# List of hosts to monitor 
HOSTS=("example1.com 192.168.1.1" "example2.com 192.168.1.2" "example3.com 192.168.1.3")
```
### 4. Schedule the Script with Cron
[crontab.guru](https://crontab.guru/examples.html)
```bash
crontab -e
# Add a cron job to run the script at your desired interval
0 * * * * /path/to/main.sh
```
