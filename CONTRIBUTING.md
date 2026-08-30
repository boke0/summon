# Summon の開発

Summon のビルド、テスト、リリースに関するメンテナー向けの情報をまとめています。プラグインを作成する場合は、[プラグイン仕様](docs/PLUGIN.md) も参照してください。

## 開発環境

- macOS 14 以降
- Xcode に付属する Swift ツールチェーン
- [`jq`](https://jqlang.github.io/jq/)
- Python 3（`regex` プラグイン）

現在の開発環境は macOS 26 / Swift 6.3 です。Homebrew を利用している場合は、次のコマンドで `jq` をインストールできます。

```sh
brew install jq
```

## ビルドとテスト

Swift パッケージをビルドし、テストを実行します。

```sh
swift build
swift test
```

## アプリバンドルの作成

```sh
Scripts/build-app.sh
open dist/Summon.app
```

アプリは `dist/Summon.app` に生成されます。バンドル ID は `com.boke0.summon` で、ad hoc 署名を施します。

ビルドスクリプトは、リリースビルドした実行ファイルと次のプラグインをアプリバンドルへコピーします。

- `Examples/echo-plugin`
- `plugins/apps`
- `plugins/cursor`
- `plugins/regex`

## Nightly リリース

`master` ブランチへ push すると、`.github/workflows/release.yml` が次の処理を実行します。

1. `macos-26` ランナーで `Scripts/build-app.sh` を実行する
2. `dist/Summon.app` を `dist/Summon.zip` に圧縮する
3. `nightly` プレリリースを作成または更新する
4. `Summon.zip` をリリースアセットとして配置する

既存の `nightly` リリースがある場合は、アセット、対象コミット、リリースノートを最新の `master` に合わせて更新します。
