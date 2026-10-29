#!/bin/bash
# LINE に1通送る。LINE_USER_ID があればその人に（push）、なければ公式アカウントの友だち全員に（broadcast）。
# 監視用の公式アカウントは友だちがオーナーだけなので、broadcast でも届く先は同じ。
set -e
text=$1
if [ -n "$LINE_TO" ]; then
  url=https://api.line.me/v2/bot/message/push
  body=$(jq -n --arg to "$LINE_TO" --arg t "$text" '{to:$to, messages:[{type:"text", text:$t}]}')
else
  url=https://api.line.me/v2/bot/message/broadcast
  body=$(jq -n --arg t "$text" '{messages:[{type:"text", text:$t}]}')
fi
curl -sS --fail-with-body -X POST "$url" -H "Authorization: Bearer $LINE_TOKEN" -H 'Content-Type: application/json' -d "$body"
