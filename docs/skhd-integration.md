# skhd 連携設定ガイド

alpatile は `skhd` から呼び出すことで、ホットキー経由で瞬時にウィンドウを操作できます。
現行の yabai 設定と 1:1 に対応しています。

## 1. `.skhdrc` の設定例

`~/.skhdrc`（または `~/phigasui/dotfiles/.skhdrc`）に以下を記述します：

```bash
# ==============================================================================
# alpatile window management (yabai からの移行)
# ==============================================================================

# window の移動 (Warp)
ctrl + cmd - h : alpatile window --warp west
ctrl + cmd - j : alpatile window --warp south
ctrl + cmd - k : alpatile window --warp north
ctrl + cmd - l : alpatile window --warp east

# layout の切り替え
## 指定ウィンドウを全画面表示 (float + maximize)
ctrl + cmd - f : alpatile space --layout float && alpatile window --maximize

## 等分割 (BSP)
ctrl + cmd - b : alpatile space --layout bsp

## 分割方向のローテート (90度回転)
ctrl + cmd - r : alpatile space --rotate 90

## 水平/垂直分割の切り替え & バランス均等化
ctrl + cmd - s : alpatile window --toggle split && alpatile space --balance
```

## 2. コマンド対応表（yabai vs alpatile）

| 操作 | yabai コマンド | alpatile コマンド |
| :--- | :--- | :--- |
| 左へ Warp | `yabai -m window --warp west` | `alpatile window --warp west` |
| 下へ Warp | `yabai -m window --warp south` | `alpatile window --warp south` |
| 上へ Warp | `yabai -m window --warp north` | `alpatile window --warp north` |
| 右へ Warp | `yabai -m window --warp east` | `alpatile window --warp east` |
| 最大化 | `yabai -m space --layout float && yabai -m window --grid 1:1:0:0:1:1` | `alpatile space --layout float && alpatile window --maximize` |
| BSP 配置 | `yabai -m space --layout bsp` | `alpatile space --layout bsp` |
| 90度回転 | `yabai -m space --rotate 90` | `alpatile space --rotate 90` |
| 分割方向トグル & 均等化 | `yabai -m window --toggle split; yabai -m space --balance` | `alpatile window --toggle split && alpatile space --balance` |

## 3. 設定の反映

`skhd` の再起動または設定再読み込み：

```bash
skhd -r
# または
brew services restart skhd
```
