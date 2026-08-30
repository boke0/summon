# プラグイン契約

summon のプラグインは、マニフェスト付きのディレクトリです。コアは JSON の stdin/stdout だけでプラグインと通信します。言語は問いません。

## 配置場所

| 場所 | 用途 |
| --- | --- |
| `Summon.app/Contents/Resources/plugins/<name>/` | 同梱プラグイン |
| `~/.config/summon/plugins/<name>/` | ユーザプラグイン |

同一 `name` のプラグインが両方にある場合は、ユーザ側が同梱側を上書きします。

コアは各配置場所の**直下 1 段**だけを走査します。`plugin.json` が読めて契約を満たすディレクトリだけがロードされます。

## `plugin.json`

```json
{
  "name": "apps",
  "title": "Apps",
  "search": ["bin/search"],
  "action": ["bin/action"]
}
```

| フィールド | 意味 |
| --- | --- |
| `name` | 設定の `tabs` と対応する識別子。必須、空文字不可 |
| `title` | UI のタブ名 |
| `search` | 検索コマンド。先頭が実行ファイル、以降は固定引数 |
| `action` | アクションコマンド。同様 |

パスはプラグインディレクトリからの相対、または絶対パスです。作業ディレクトリはプラグインディレクトリです。

## search

起動: `<search-cmd> <query>`

- `query` は必ず渡します。空クエリでも引数は付きます（空文字列）。
- stdout は次の JSON のみ（ログは stderr へ）。

```json
{
  "items": [
    {
      "id": "safari",
      "title": "Safari",
      "subtitle": "Browser",
      "icon": "/Applications/Safari.app",
      "payload": { "bundleId": "com.apple.Safari" }
    }
  ]
}
```

| フィールド | 必須 | 意味 |
| --- | --- | --- |
| `id` | はい | 候補の識別子。リスト内で一意にしてください |
| `title` | はい | 主表示 |
| `subtitle` | いいえ | 副表示 |
| `icon` | いいえ | アイコンにするファイルパス（`.app` 可）。コアが `NSWorkspace` で描画します |
| `payload` | いいえ | アクション用の任意オブジェクト |

入力のたびに search が走ります（コア側で約 100ms デバウンス、前回プロセスはキャンセル）。

## action

- stdin: 選択された候補オブジェクト全体の JSON（search の 1 要素と同じ形）
- 終了コード `0`: コアはフローティングウィンドウを閉じます
- それ以外: ウィンドウは開いたままです

## 設定との関係

`~/.config/summon/config.json` の `tabs` は、ロード済みプラグインを **name で並べるフィルタ** です。

```json
{
  "hotkey": "cmd+d",
  "tabModifier": "cmd",
  "tabs": ["apps", "cursor", "regex"]
}
```

`tabs` に書いた name のうち、実際にロードできたものだけが左から順にタブになります。1 つも見つからない場合は、ロードできたプラグインを name 順で全部出します。

タブ切替は `tabModifier` + `1`…`9` です（デフォルト `cmd+1` …）。

## サンプル

`Examples/echo-plugin/` は空クエリで Hello / World、入力ありならその文字列を 1 件返すシェルプラグインです。action は stdin を `/tmp/summon-echo-last-action.json` に書いて exit 0 します。
