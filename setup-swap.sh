#!/bin/bash
set -e

POOL="tank"
ZVOL_NAME="swap"
ZVOL_PATH="$POOL/$ZVOL_NAME"
ZVOL_DEV="/dev/zvol/$ZVOL_PATH"
SIZE="16G"

echo "=== ZFS zvol スワップ設定 ==="
echo "  プール : $POOL"
echo "  zvol   : $ZVOL_PATH"
echo "  サイズ : $SIZE"
echo ""

# zvol 作成（既存チェックあり）
echo "[1/4] zvol 作成 ..."
if zfs list "$ZVOL_PATH" &>/dev/null; then
    echo "  既に存在します。スキップ。"
else
    sudo zfs create -V "$SIZE" \
        -b "$(getconf PAGESIZE)" \
        -o compression=off \
        -o sync=always \
        "$ZVOL_PATH"
    echo "  作成しました。"
fi

# デバイスが現れるまで待機
echo "[2/4] デバイス待機 ..."
for i in $(seq 1 10); do
    [ -b "$ZVOL_DEV" ] && break
    sleep 1
done
[ -b "$ZVOL_DEV" ] || { echo "ERROR: $ZVOL_DEV が見つかりません"; exit 1; }

# スワップフォーマット
echo "[3/4] mkswap ..."
sudo mkswap -f "$ZVOL_DEV"

# スワップ有効化
echo "[4/4] swapon + fstab 登録 ..."
sudo swapon "$ZVOL_DEV"

if grep -q "$ZVOL_DEV" /etc/fstab; then
    echo "  fstab に既に登録済みです。スキップ。"
else
    echo "$ZVOL_DEV none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "  fstab に追記しました。"
fi

echo ""
echo "=== 完了 ==="
swapon --show
free -h