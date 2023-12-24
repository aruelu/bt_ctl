#!/bin/bash

# チェック関数: Bluetoothが有効かどうか
function check_bluetooth {
    bluetooth_status=$(rfkill list bluetooth | grep -o "Soft blocked: yes")

    if [ -n "$bluetooth_status" ]; then
        echo "Bluetoothが無効になっています。有効にしてから再実行してください。"
        exit 1
    fi
}

function search_devices {
    check_bluetooth

    (bluetoothctl scan on && sleep 5) &
    search_pid=$!
    sleep_time=10
    sleep "$sleep_time"
    kill -TERM "$search_pid" >/dev/null 2>&1
    devices=$(bluetoothctl devices | grep Device)
    if [ -z "$devices" ]; then
        echo "デバイスが見つかりませんでした。終了します。"
        exit 1
    fi
    echo "利用可能なBluetoothデバイス:"
    available_devices=$(echo "$devices" | grep -v "$(bluetoothctl paired-devices | grep Device | awk '{print $2}')")
    if [ -z "$available_devices" ]; then
        echo "ペアリングモードが終了しました。終了します。"
        exit 1
    fi
    echo "$available_devices" | nl -w2 -s') '
    echo "$available_devices"
}

function pair_device {
    local device_mac=$1
    read -p "このデバイスに対してピンコードを使用しますか？ (y/n): " use_pin
    if [ "$use_pin" == "y" ]; then
        read -p "ピンコードを入力してください: " pin_code
        bluetoothctl pair "$device_mac" "$pin_code"
    else
        bluetoothctl pair "$device_mac"
    fi
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

while true; do
    read -p "機能を選択してください (1: ペアリング, 2: ペアリング解除, 0: 終了): " action

    case $action in
        1)
            echo "ペアリングするデバイスの番号を入力してください (99で再検索, 0で終了):"
            device_mac=$(search_devices)
            if [ "$device_mac" == "99" ]; then
                continue
            elif [ "$device_mac" == "0" ]; then
                echo "終了します."
                exit 0
            fi
            if ! [[ "$device_mac" =~ ^[0-9]+$ ]]; then
                echo "無効な番号が入力されました。終了します。"
                exit 1
            fi
            if [ "$device_mac" -le 0 ] || [ "$device_mac" -gt $(echo "$available_devices" | wc -l) ]; then
                echo "無効なデバイス番号が選択されました。終了します。"
                exit 1
            fi
            pair_device $(echo "$available_devices" | sed -n "${device_mac}p" | awk '{print $2}')
            break
            ;;
        2)
            paired_devices=$(bluetoothctl paired-devices | grep Device)
            if [ -z "$paired_devices" ]; then
                echo "ペアリングされたデバイスがありません。"
                exit 1
            fi
            echo "ペアリングされているBluetoothデバイス:"
            echo "$paired_devices" | nl -w2 -s') '
            read -p "削除するデバイスの番号を入力してください: " device_number
            if ! [[ "$device_number" =~ ^[0-9]+$ ]]; then
                echo "無効な番号が入力されました。終了します。"
                exit 1
            fi
            if [ "$device_number" -le 0 ] || [ "$device_number" -gt $(echo "$paired_devices" | wc -l) ]; then
                echo "無効なデバイス番号が選択されました。終了します。"
                exit 1
            fi
            device_mac=$(echo "$paired_devices" | sed -n "${device_number}p" | awk '{print $2}')
            if [ -z "$device_mac" ]; then
                echo "無効なデバイス番号が選択されました。終了します。"
                exit 1
            fi
            unpair_device "$device_mac"
            ;;
        0)
            echo "終了します."
            exit 0
            ;;
        *)
            echo "無効な操作が選択されました。終了します。"
            exit 1
            ;;
    esac
done

echo "Bluetoothデバイス:"
bluetoothctl devices | grep Device | nl -w2 -s') '
echo "ペアリングされているBluetoothデバイス:"
bluetoothctl paired-devices | grep Device | nl -w2 -s') '