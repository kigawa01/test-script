#!/bin/bash
set -e

SWAP_DEV="/dev/nvme1n1p3"

echo "=== スワップ設定: $SWAP_DEV ==="

# スワップフォーマット
echo "[1/3] mkswap ..."
sudo mkswap "$SWAP_DEV"

# スワップ有効化
echo "[2/3] swapon ..."
sudo swapon "$SWAP_DEV"

# fstab に追記（重複チェックあり）
echo "[3/3] /etc/fstab に追記 ..."
if grep -q "$SWAP_DEV" /etc/fstab; then
    echo "  既に fstab に登録済みです。スキップ。"
else
    echo "$SWAP_DEV none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "  追記しました。"
fi

echo ""
echo "=== 完了 ==="
swapon --show
free -h