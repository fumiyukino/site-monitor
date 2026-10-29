# site-monitor

運営しているサイトが開けるか、SSL 証明書の期限が近くないかを、5分おきに確かめる。

- 見張るサイト：[sites.tsv](sites.tsv)（サイトを足すときは1行足す）
- チェックの中身：[check.sh](check.sh)（`./check.sh` で手元でも動く）
- 最新の状態：[summary.md](summary.md)（毎朝9時に更新）

## 通知

新しく異常が出たときと、直ったときだけ知らせる。異常が続いているあいだは、何度も知らせない。

- **メール**：新しく異常が出ると GitHub Actions が失敗し、GitHub から失敗のメールが届く
- **LINE**：リポジトリの Secrets に `LINE_CHANNEL_ACCESS_TOKEN` を入れると、監視用の公式アカウントの友だち（オーナー）に届く。`LINE_USER_ID` も入れればその人だけに送る

SSL 証明書は、残りが21日を切ったら異常として扱う。

このリポジトリは公開にしている（GitHub Actions を無料で使い放題にするため）。トークンやパスワードは置かず、すべて Secrets に入れること。

## LINE に話しかけると今の状態を返す

監視用の LINE 公式アカウントに何か送ると、6サイトをその場で開いて確かめ、状態とリンクを返す。
[line-bot/](line-bot/) の Cloudflare Worker（https://site-monitor-line.fino-bd8.workers.dev）が LINE の Webhook を受けている。

- 更新：`cd line-bot && npx wrangler@4 deploy`（Cloudflare アカウント fino@crecom.biz）
- 秘密の値は Cloudflare の画面（Workers & Pages → site-monitor-line → 設定）の `LINE_CHANNEL_SECRET`・`LINE_CHANNEL_ACCESS_TOKEN`
- 見張るサイトはこのリポジトリの sites.tsv を読むので、サイトを足すときは sites.tsv だけ直せばよい
