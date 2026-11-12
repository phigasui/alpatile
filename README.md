# alpatile

macOS 向けの超軽量・低チラツキ（Low-Flicker）ウィンドウタイリングツール。

yabai の複雑さや SIP 依存、macOS Sonoma / Sequoia における Electron / Chromium 系アプリでの激しいチラツキ・振動（Stutter-resizing）を排除し、必要な 8 つのキー操作に特化した純粋 Swift 実装です。

## 特長

1. **完全 SIP 有効（System Integrity Protection）対応**: Dock へのインジェクションや非公開 WindowServer API に依存せず、純粋な Accessibility API で動作します。
2. **チラツキ・振動（Stuttering）の徹底抑制**:
   - `AXEnhancedUserInterface` の一時無効化により、Electron / Chromium アプリ（Chrome, VS Code, Slack 等）の補間アニメーション衝突を防止。
   - `Size -> Position -> Size` の安全順序制御による画面外クランプ防止。
   - 1px ガード（No-op 判定）により不要な AX API 発行を排除。
3. **超高速・軽量**:
   - バックグラウンドデーモン（`alpatiled`）と UNIX ドメインソケット経由で通信する CLI（`alpatile`）。
   - CLI 実行オーバーヘッドは 1ms 未満。
4. **現行の `.skhdrc` と 1:1 対応**:
   - Warp（4方向）、Split Toggle、Rotate 90、Balance、BSP/Float 切り替え、Maximize を網羅。

---

## 必要環境

- macOS 13 (Ventura) / macOS 14 (Sonoma) / macOS 15 (Sequoia) 以降
- Swift 6.0+

---

## ビルドとインストール

### 1. ビルド

```bash
swift build -c release
```

### 2. インストール

バイナリを `~/.local/bin` に配置します（シンボリックリンク `ln -sf` 推奨。`~/.local/bin` に `PATH` を通しておいてください）：

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/.build/release/alpatile" ~/.local/bin/alpatile
ln -sf "$(pwd)/.build/release/alpatiled" ~/.local/bin/alpatiled
```

> `cp` によるコピー配置も可能ですが、`ln -sf` を使うと再ビルド後に配置先のバイナリがそのまま最新化されます。

### 3. 常駐デーモンの起動 (launchd)

`launchd/com.phigasui.alpatiled.plist` の `ProgramArguments`（既定: `/Users/phigasui/.local/bin/alpatiled`）がご自身の環境と一致しているか確認・必要なら修正したうえで、`~/Library/LaunchAgents/` へ配置して登録します（`launchd` の plist 内では `~` や `$HOME` は展開されないためフルパスが必要です）：

```bash
mkdir -p ~/Library/LaunchAgents
cp launchd/com.phigasui.alpatiled.plist ~/Library/LaunchAgents/
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.phigasui.alpatiled.plist
```

よく使う `launchctl` 操作・ログ確認：

```bash
# 状態確認
launchctl print "gui/$(id -u)/com.phigasui.alpatiled"

# 再起動（ビルド差し替え後や権限再許可後）
launchctl kickstart -k "gui/$(id -u)/com.phigasui.alpatiled"

# 停止・登録解除
launchctl bootout "gui/$(id -u)/com.phigasui.alpatiled"

# 標準出力・標準エラーログの確認
cat /tmp/alpatiled.out.log
cat /tmp/alpatiled.err.log
```

> **重要（アクセシビリティ権限と再ビルド時の再許可）**:
> - 初回起動時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で `alpatiled` への権限許可が必要です（未許可の場合 `/tmp/alpatiled.err.log` に警告が出力されます）。
> - **`swift build -c release` で再ビルドするとバイナリの署名（CDHash）が変わるため、システム設定上でチェックが入っていてもアクセシビリティ権限が失効します。** 再ビルド後はアクセシビリティ一覧から既存の `alpatiled` エントリを一度削除（`-`）して再追加（`+`）し、`launchctl kickstart -k "gui/$(id -u)/com.phigasui.alpatiled"` でデーモンを再起動してください。

手動でフォアグラウンド起動して動作確認する場合（`launchd` で稼働中に 2 つ目を起動すると排他ロックにより既存ソケットを壊さず終了するため、事前に `launchctl bootout` で停止してください）：
```bash
~/.local/bin/alpatiled
```

---

## 設定ファイル

設定ファイルは `~/.config/alpatile/config.json`（省略時はデフォルト値が適用されます）：

```json
{
  "topPadding": 0,
  "bottomPadding": 0,
  "leftPadding": 0,
  "rightPadding": 0,
  "windowGap": 0,
  "ignoreApps": [
    "DeepL",
    "System Settings",
    "システム環境設定",
    "Finder"
  ]
}
```

設定を編集した後は `alpatile reload` で反映されます。

---

## コマンド一覧

```bash
# ウィンドウの Warp（隣接ウィンドウとの位置交換）
alpatile window --warp west
alpatile window --warp south
alpatile window --warp north
alpatile window --warp east

# カレントノードの分割方向切替（水平 / 垂直）
alpatile window --toggle split

# 最大化（全画面表示）
alpatile window --maximize

# ツリーを 90 度回転
alpatile space --rotate 90

# 全ウィンドウを 1:1 均等比率にバランス
alpatile space --balance

# レイアウトモード切替
alpatile space --layout bsp
alpatile space --layout float

# 状態確認・デバッグ
alpatile query status
alpatile query windows
alpatile reload
alpatile ping
```

---

## skhd との連携

詳細な設定手順は [docs/skhd-integration.md](docs/skhd-integration.md) を参照してください。

---

## テストの実行

```bash
swift test
```
