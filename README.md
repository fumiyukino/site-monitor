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
