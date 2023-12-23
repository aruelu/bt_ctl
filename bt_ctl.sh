#!/bin/bash

function search_devices {
    # Bluetoothデバイスの検索をバックグラウンドで実行
    (bluetoothctl scan on && sleep 5) &

    # バックグラウンドで実行しているプロセスのPIDを取得
    search_pid=$!

    # 一定時間待つ
    sleep_time=10
    sleep "$sleep_time"

    # バックグラウンドで実行しているプロセスをkill
    kill -TERM "$search_pid" >/dev/null 2>&1

    # 検索結果のBluetoothデバイスを表示
    devices=$(bluetoothctl devices | grep Device)

    # 利用可能なBluetoothデバイスを番号を振って表示
    echo "利用可能なBluetoothデバイス:"
    available_devices=$(echo "$devices" | grep -v "$(bluetoothctl paired-devices | grep Device | awk '{print $2}')")
    echo "$available_devices" | nl -w2 -s') '

    # デバイスの番号を取得
    read -p "デバイスの番号を入力してください (0で終了): " device_number

    if [ "$device_number" -eq 0 ]; then
        echo "終了します。"
        exit 0
    fi

    # デバイスのMACアドレスを抽出
    device_mac=$(echo "$available_devices" | sed -n "${device_number}p" | awk '{print $2}')

    if [ -z "$device_mac" ]; then
        echo "無効なデバイス番号が選択されました。"
        exit 1
    fi

    echo "$device_mac"
}

function pair_device {
    local device_mac=$1
    bluetoothctl pair "$device_mac"
}

function unpair_device {
    local device_mac=$1
    if echo "$(bluetoothctl paired-devices | grep Device)" | grep -q "$device_mac"; then
        bluetoothctl remove "$device_mac"
    else
        echo "選択されたデバイスはペアリングされていません。"
        exit 1
    fi
}

# ペアリングまたは削除を選択
read -p "機能を選択してください (1: ペアリング, 2: ペアリング解除, 0: 終了): " action

case $action in
    1)
        # ペアリング
        echo "ペアリングするデバイスの番号を入力してください:"
        device_mac=$(search_devices)
        pair_device "$device_mac"
        ;;
    2)
        # ペアリング解除
        paired_devices=$(bluetoothctl paired-devices | grep Device)
        if [ -z "$paired_devices" ]; then
            echo "ペアリングされたデバイスがありません。"
            exit 1
        fi

        # ペアリングされたデバイスを番号を振って表示
        echo "ペアリングされているBluetoothデバイス:"
        echo "$paired_devices" | nl -w2 -s') '

        # デバイスの番号を取得
        read -p "削除するデバイスの番号を入力してください: " device_number

        # ペアリング解除対象のデバイスのMACアドレスを抽出
        device_mac=$(echo "$paired_devices" | sed -n "${device_number}p" | awk '{print $2}')

        if [ -z "$device_mac" ]; then
            echo "無効なデバイス番号が選択されました。"
            exit 1
        fi

        unpair_device "$device_mac"
        ;;
    0)
        echo "終了します."
        exit 0
        ;;
    *)
        echo "無効な操作が選択されました。"
        exit 1
        ;;
esac

# ペアリングまたは解除後のBluetoothデバイスの一覧を表示
echo "Bluetoothデバイス:"
bluetoothctl devices | grep Device | nl -w2 -s') '
echo "ペアリングされているBluetoothデバイス:"
bluetoothctl paired-devices | grep Device | nl -w2 -s') '