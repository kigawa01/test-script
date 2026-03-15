#!/bin/bash
set -euo pipefail

BACKUP_DEST="/mnt/cephfs/user/back/2026-03-16/home"
TANK_HOME_DATASET="tank/home"
RPOOL_HOME_DATASET="rpool/USERDATA/home_x0l9f9"

info()  { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# ── Phase 1: tank/home → cephfs バックアップ ────────────────────────────────
phase1_backup() {
    info "Phase 1: tank/home を cephfs にバックアップ"
    [[ -d /tank/home ]] || error "/tank/home が存在しません"
    mkdir -p "$BACKUP_DEST"
    rsync -a --info=progress2 /tank/home/ "$BACKUP_DEST"/
    info "Phase 1 完了"
}

# ── Phase 2: rpool/home → tank/home 移動 ────────────────────────────────────
# シングルユーザーモードで実行すること
phase2_migrate() {
    info "Phase 2: rpool/home を tank/home に移動"

    # ログインユーザー確認（root 以外がいたら中止）
    local logged_in
    logged_in=$(who | grep -v "^root" | wc -l)
    [[ "$logged_in" -eq 0 ]] || error "root 以外のユーザーがログイン中です。シングルユーザーモードで実行してください"

    # /home が rpool にマウントされているか確認
    local current_ds
    current_ds=$(zfs list -H -o name "$(df --output=source /home | tail -1)" 2>/dev/null || true)
    [[ "$current_ds" == "$RPOOL_HOME_DATASET" ]] || error "/home が $RPOOL_HOME_DATASET にマウントされていません（現在: $current_ds）"

    info "rpool/home → tank/home へ rsync 中..."
    rsync -a --delete --info=progress2 /home/ /tank/home/

    info "tank/home のマウントポイントを /home に変更..."
    zfs unmount "$TANK_HOME_DATASET" || true
    zfs set mountpoint=/home "$TANK_HOME_DATASET"
    zfs mount "$TANK_HOME_DATASET"

    info "rpool の /home をアンマウント..."
    zfs unmount "$RPOOL_HOME_DATASET" || true
    zfs set mountpoint=none "$RPOOL_HOME_DATASET"

    info "確認: /home の ZFS データセット"
    zfs list "$TANK_HOME_DATASET"
    ls /home/

    info "Phase 2 完了"
    info "確認後に以下を実行して rpool のデータセットを削除:"
    info "  sudo zfs destroy $RPOOL_HOME_DATASET"
}

# ── Phase 3: rpool/home データセット削除 ────────────────────────────────────
phase3_cleanup() {
    info "Phase 3: rpool の home データセットを削除"
    local mp
    mp=$(zfs get -H -o value mountpoint "$RPOOL_HOME_DATASET" 2>/dev/null || true)
    [[ "$mp" == "none" ]] || error "$RPOOL_HOME_DATASET がまだマウントされています（mountpoint=$mp）。Phase 2 を先に完了してください"

    zfs destroy "$RPOOL_HOME_DATASET"
    info "Phase 3 完了: $RPOOL_HOME_DATASET を削除しました"
}

# ── エントリポイント ──────────────────────────────────────────────────────────
case "${1:-}" in
    phase1)   phase1_backup ;;
    phase2)   phase2_migrate ;;
    phase3)   phase3_cleanup ;;
    *)
        echo "使い方: $0 <phase1|phase2|phase3>"
        echo ""
        echo "  phase1  tank/home を cephfs にバックアップ（通常起動で実行可）"
        echo "  phase2  rpool/home を tank/home に移動（シングルユーザーモード推奨）"
        echo "  phase3  rpool の home データセットを削除（phase2 完了後）"
        exit 1
        ;;
esac