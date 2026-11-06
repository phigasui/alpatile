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

バイナリをパスの通った場所（例: `/usr/local/bin`）に配置します：

```bash
sudo cp .build/release/alpatile /usr/local/bin/
sudo cp .build/release/alpatiled /usr/local/bin/
```

### 3. 常駐デーモンの起動 (launchd)

```bash
mkdir -p ~/Library/LaunchAgents
cp launchd/com.phigasui.alpatiled.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.phigasui.alpatiled.plist
```

※ 初回起動時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で `alpatiled` への権限許可が必要です。

手動でフォアグラウンド起動して動作確認する場合：
```bash
/usr/local/bin/alpatiled
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
