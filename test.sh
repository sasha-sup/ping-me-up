#!/bin/bash

# Fetch the HTML content of the page
html_content=$(curl -s "https://www.google.com/finance/quote/BTC-USD?hl=en")

# Extract the desired element using XPath and grep
element_value=$(echo "$html_content" | grep -oP '/html/body/c-wiz[3]/div/div[4]/div/main/div[2]/div[1]/div[1]/c-wiz/div/div[1]/div/div[1]/div/div[1]/div/span/div/div')

# Output the extracted element value
echo "Element value: $html_content"
