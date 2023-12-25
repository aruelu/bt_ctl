#!/bin/bash

# チェック関数: Bluetoothが有効かどうか
function check_bluetooth {
    if ! command -v bluetoothctl &> /dev/null; then
        echo "Bluetoothの機能が利用できません。終了します。"
        exit 1
    fi

    bluetooth_status=$(rfkill list bluetooth )
    #if [ -n "$bluetooth_status" ]; then
        #echo "Bluetoothが無効になっています。有効にしてから再実行してください。"
        #exit 1
    #elif [ "$bluetooth_status" == "" ]; then
        #echo "Bluetoothが無効になっています。有効にしてから再実行してください。"
        #exit 1
    #fi
    if [ "$bluetooth_status" == "" ]; then
        echo "Bluetoothが無効になっています。有効にしてから再実行してください。"
        exit 1
    fi
}


function search_devices {
    bluetoothctl scan on  &
    search_pid=$!
    sleep_time=10
    sleep "$sleep_time"
    kill -TERM "$search_pid" >/dev/null 2>&1
    devices=$(bluetoothctl devices | grep Device)
echo "$devices"
    if [ -z "$devices" ]; then
        echo "デバイスが見つかりませんでした。終了します。"
        exit 1
    fi
    echo "利用可能なBluetoothデバイス:"
    echo "$devices" | nl -w2 -s') '
    #available_devices=$(echo "$devices" |  grep "Device" | awk '{print $2}')
    available_devices="$devices"
#    if [ -z "$available_devices" ]; then
#        echo "ペアリングモードが終了しました。終了します。"
#        exit 1
#    fi
    #echo "$available_devices" | nl -w2 -s') '
    #echo "$available_devices"
    read -p "ペアリングするデバイスの番号を入力してください (99で再検索, 0で終了)：" device_number
}

function pair_device {
    local device_mac=$1
    echo "$device_mac"
    read -p "このデバイスに対してピンコードを使用しますか？ (y/n): " use_pin
    if [ "$use_pin" == "y" ]; then
        read -p "ピンコードを入力してください: " pin_code
        result=$(bluetoothctl pair "$device_mac" "$pin_code" | grep "Device has been paired")
    else
        result=$(bluetoothctl pair "$device_mac" | grep "Device has been paired")
    fi

    if [ -n "$result" ]; then
        echo "ペアリングが成功しました。"
        connect_device "$device_mac"
    else
        echo "ペアリングが失敗しました。終了します。"
        exit 1
    fi
}

function connect_device {
    local device_mac=$1
    bluetoothctl connect "$device_mac"
        # 接続が成功したかどうかの確認
    connected_devices=$(bluetoothctl info | grep "Connected: yes")
    
    if [ -n "$connected_devices" ]; then
        echo "デバイスが正常に接続されました。"
    else
        echo "デバイスの接続が失敗しました。"
        # 何か失敗時の処理を追加する場合はここに追加
        exit 1
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

#メイン処理

# Bluetoothの有効性をチェック
check_bluetooth

while true; do
    read -p "機能を選択してください (1: ペアリング, 2: ペアリング解除, 0: 終了): " action

    case $action in
        1)
            echo "デバイスの検索中・・・"
            search_devices
            #device_mac=$(search_devices)
            if [ "$device_number" == "99" ]; then
                continue
            elif [ "$device_number" == "0" ]; then
                echo "終了します."
                exit 0
            fi
            if ! [[ "$device_number" =~ ^[0-9]+$ ]]; then
                echo "無効な番号が入力されました。終了します。"
                exit 1
            fi
            if [ "$device_number" -le 0 ] || [ "$device_number" -gt $(echo "$available_devices" | wc -l) ]; then
                echo "無効なデバイス番号が選択されました。終了します。"
                exit 1
            fi
            pair_device $(echo "$available_devices" | sed -n "${device_number}p" | awk '{print $2}')
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
