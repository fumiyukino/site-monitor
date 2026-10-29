#!/bin/bash
# sites.tsv の各サイトを開いて、ステータス・PHP の致命的エラー・SSL 期限を確かめる。
# 異常が1つでもあれば exit 1（GitHub Actions が失敗 → メール通知）。
# 結果は status.json と、人が読む要約 summary.md、LINE 用の一覧 line_status.txt（サイトごとに印・名前・リンク）に書き出す。
SSL_WARN_DAYS=${SSL_WARN_DAYS:-21}
now=$(date -u +%s)
problems=()
rows=()
line_rows=()
json='[]'

while IFS=$'\t' read -r name url ok_codes host; do
  [[ -z "$name" || "$name" == \#* ]] && continue

  body=$(mktemp)
  code=""
  for attempt in 1 2; do   # 一瞬の通信エラーで騒がないよう、失敗したら1回だけやり直す
    code=$(curl -s -o "$body" -m 30 -A 'site-monitor (fumiyukino)' -w '%{http_code}' "$url")
    [[ "|$ok_codes|" == *"|$code|"* ]] && break
    sleep 10
  done
  time_ms=$(curl -s -o /dev/null -m 30 -w '%{time_total}' "$url" | awk '{printf "%d", $1*1000}')

  state="正常"; note=""
  if [[ "|$ok_codes|" != *"|$code|"* ]]; then
    state="異常"; note="HTTP $code（期待値 $ok_codes）"
  elif grep -qiE 'critical error|重大なエラー|Fatal error|Parse error|データベース接続確立エラー|Error establishing a database connection' "$body"; then
    state="異常"; note="ページに PHP / DB のエラーが出ている"
  fi
  rm -f "$body"

  end=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [[ -n "$end" ]]; then
    end_s=$(date -u -d "$end" +%s 2>/dev/null || date -u -j -f '%b %e %T %Y %Z' "$end" +%s)
    days=$(( (end_s - now) / 86400 ))
    if (( days < SSL_WARN_DAYS )); then
      state="異常"; note="${note:+$note / }SSL 証明書があと ${days} 日で切れる"
    fi
  else
    days=""; state="異常"; note="${note:+$note / }SSL 証明書を読めない"
  fi

  [[ "$state" == "異常" ]] && problems+=("⚠️ ${name}：${note}"$'\n'"$url")
  if [[ "$state" == "異常" ]]; then line_rows+=("⚠️ ${name}：${note}"$'\n'"$url"); else line_rows+=("✅ ${name}（${time_ms}ms）"$'\n'"$url"); fi
  rows+=("| $name | $state | $code | ${time_ms}ms | ${days:-?} 日 | $note |")
  json=$(jq -c --arg n "$name" --arg u "$url" --arg s "$state" --arg c "$code" \
    --argjson t "${time_ms:-0}" --arg d "$days" --arg note "$note" \
    '. + [{name:$n,url:$u,state:$s,http:$c,ms:$t,ssl_days:($d|tonumber? // null),note:$note}]' <<<"$json")
done < "$(dirname "$0")/sites.tsv"

checked_at=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
jq -n --arg at "$checked_at" --argjson sites "$json" '{checked_at:$at, sites:$sites}' > status.json

{
  echo "## サイト監視 $checked_at"
  echo
  echo "| サイト | 状態 | HTTP | 応答 | SSL 残り | メモ |"
  echo "|---|---|---|---|---|---|"
  printf '%s\n' "${rows[@]}"
} > summary.md
cat summary.md
( IFS=$'\n'; printf '%s\n\n' "${line_rows[@]}" ) > line_status.txt

if (( ${#problems[@]} > 0 )); then
  printf '%s\n\n' "${problems[@]}" > problems.txt
  echo; echo "異常あり:"; cat problems.txt
  exit 1
fi
rm -f problems.txt
