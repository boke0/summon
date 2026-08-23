# Summon

ホットキーで開く、macOS 向けのフローティングランチャです。候補の検索と実行は外部プロセス型プラグインに任せます。

コア、動作確認用の echo プラグイン、アプリ起動プラグイン（`apps`）、Cursor ワークスペースプラグイン（`cursor`）までが動きます。

## 必要環境

- macOS 14 以降（開発は macOS 26 / Swift 6.3）
- Xcode 付属の Swift ツールチェーン
- [`jq`](https://jqlang.github.io/jq/)（`brew install jq`。同梱プラグインの action が候補 JSON のパースに使う）

## ビルド

```sh
swift build && swift test
Scripts/build-app.sh
open dist/Summon.app
```

`dist/Summon.app` はメニューバー常駐（Dock には出ません）。バンドル ID は `com.boke0.summon` で、ad-hoc 署名します。

## 使い方

1. デフォルトホットキー `cmd+d` でパネルを開く（もう一度押すと閉じる）
2. 検索欄に入力すると、アクティブタブの search が走ります
3. `↑` `↓` で候補移動、`Enter` で action、`Esc` で閉じる
4. `cmd+1` … `cmd+9` でタブ切替（`tabModifier` で変更可）
5. メニューバーの虫眼鏡 → Open / Quit

## 設定

`~/.config/summon/config.json`（無ければデフォルト）:

```json
{
  "hotkey": "cmd+d",
  "tabModifier": "cmd",
  "tabs": ["apps", "cursor"]
}
```

ホットキー例: `cmd+d` / `ctrl+shift+space`。修飾キーは `cmd` `command` `ctrl` `control` `opt` `option` `alt` `shift`。

設定はパネルを開くときに読み直します。ホットキー本体は、次回ホットキー押下またはメニューの Open のあと新しい組み合わせに付け替わります。

## プラグイン

契約は [docs/PLUGIN.md](docs/PLUGIN.md) を見てください。

- 同梱: `Summon.app/Contents/Resources/plugins/`
- ユーザ: `~/.config/summon/plugins/`

同梱プラグインは `echo`（動作確認）、`apps`（アプリ起動）、`cursor`（ワークスペース）です。デフォルトの `tabs` は `apps` / `cursor` です。

## Apps プラグイン

`apps` タブは次の場所の `.app` を再帰的に走査し、表示名の前方一致（大文字小文字無視、1文字から）で絞り込みます。空クエリではスキャンした全アプリを名前順で出します。`.app` バンドルの中は降りません。

- `/Applications`
- `/System/Applications`
- `~/Applications`

`icon` は `.app` パスです（コアが `NSWorkspace` で描画）。実行中でウィンドウが複数あるアプリは、`アプリ名 — ウィンドウタイトル` の候補も出します。ウィンドウの列挙とフォーカスにはアクセシビリティ権限が必要で、初回起動時に設定を開く案内が出ます。

```sh
plugins/apps/bin/search ''
plugins/apps/bin/search S
```

## echo プラグインの CLI 確認

```sh
Examples/echo-plugin/bin/search ''
Examples/echo-plugin/bin/search hello
printf '{"id":"echo","title":"hello","subtitle":"Echo back your query","payload":{"text":"hello"}}' \
  | Examples/echo-plugin/bin/action
cat /tmp/summon-echo-last-action.json
```

## Cursor プラグイン

タブ名は `cursor`（`config.json` の `tabs` と一致）。ホーム直下の `@*` ディレクトリの直下フォルダを列挙し、`@組織/プロジェクト` を候補タイトルにします。空クエリでは全プロジェクトに加えて **Agents** を出します。入力ありならタイトルの部分一致（大文字小文字無視、`grep -iF`）で絞り込みます。

選択したフォルダは Cursor の同梱 CLI（`--classic`）で開きます。Agents は System Events でメニュー **Window > Cursor Agents**（なければ **File > Switch to Agents Window** / **New Agents Window**）をクリックします。Summon にアクセシビリティ権限が必要です。

```sh
plugins/cursor/bin/search ''
plugins/cursor/bin/search foo
```
