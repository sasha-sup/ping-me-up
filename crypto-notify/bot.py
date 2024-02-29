import os
import time
import requests
from bs4 import BeautifulSoup
import telebot

UPDATE_INTERVAL = "1800"
TOKEN = os.getenv('BOT_TOKEN')
CHAT_ID = os.getenv('CHAT_ID')

URLS = [
    "https://coinmarketcap.com/currencies/bitcoin",
    "https://coinmarketcap.com/currencies/ethereum",
    "https://coinmarketcap.com/currencies/tether",
    "https://coinmarketcap.com/currencies/dogecoin",
    "https://coinmarketcap.com/currencies/shiba-inu"
]

def get_currency_price(url):
    try:
        response = requests.get(url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            price_element = soup.find('span', class_='sc-f70bb44c-0 jxpCgO base-text')
            # For shiba
            if not price_element:
                price_element = soup.find('span', class_='sc-f70bb44c-0 eZIItc base-text')
            if price_element:
                return price_element.text.strip()
    except Exception as e:
        print(f"Error: {e}")
    return None

bot = telebot.TeleBot(TOKEN)

def send_prices():
    message = ""
    for url in URLS:
        currency_name = url.split('/')[-1]
        price = get_currency_price(url)
        if price:
            message += f"{currency_name}: {price}\n"
        else:
            message += f"Failed to fetch price for {currency_name}\n"
    bot.send_message(CHAT_ID, message)

while True:
    send_prices()
    time.sleep(int(UPDATE_INTERVAL))
