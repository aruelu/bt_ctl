#!/bin/bash

# チェック関数: Bluetoothが有効かどうか
function check_bluetooth {
    if ! command -v bluetoothctl &> /dev/null; then
        echo "Bluetoothの機能が利用できません。終了します。"
        exit 1
    fi

    bluetooth_status=$(rfkill list bluetooth )
    if [ "$bluetooth_status" == "" ]; then
        echo "Bluetoothが無効になっています。有効にしてから再実行してください。"
        exit 1
    fi
    blocked=$(echo "$bluetooth_status" | grep "yes")
    if [ "$blocked" != "" ]; then
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
    #devices=$(bluetoothctl devices | grep Device)
    devices=$(bluetoothctl devices | grep Device | grep  -vE "[A-Z0-9]{2}-[A-Z0-9]{2}-[A-Z0-9]{2}-[A-Z0-9]{2}-[A-Z0-9]{2}-[A-Z0-9]{2}")
echo "$devices"
    if [ -z "$devices" ]; then
        echo "デバイスが見つかりませんでした。終了します。"
        exit 1
    fi
    echo "利用可能なBluetoothデバイス:"
    echo "$devices" | nl -w2 -s') '
    available_devices="$devices"
    read -p "ペアリングするデバイスの番号を入力してください (99で再検索, 0で終了)：" device_number
}

#!/bin/bash

function trust_device {
    local device_mac=$1
    local max_retries=3
    local retry_count=0

    while [ "$retry_count" -lt "$max_retries" ]; do
        bluetoothctl trust "$device_mac"

        # 信頼設定が成功したかどうかの確認
        trusted_devices=$(bluetoothctl info "$device_mac" | grep "Trusted: yes")

        if [ -n "$trusted_devices" ]; then
            echo "デバイスが正常に信頼設定されました。"
            return 0  # 成功した場合は関数を終了
        else
            echo "デバイスの信頼設定が失敗しました。再試行します。"
            retry_count=$((retry_count + 1))
            sleep 2  # 一定時間待ってから再試行
        fi
    done

    echo "デバイスの信頼設定が $max_retries 回試行しても失敗しました。"
    exit 1
}

function connect_device {
    local device_mac=$1
    local max_retries=3
    local retry_count=0

    while [ "$retry_count" -lt "$max_retries" ]; do
        bluetoothctl connect "$device_mac"

        # 接続が成功したかどうかの確認
        connected_devices=$(bluetoothctl info "$device_mac" | grep "Connected: yes")

        if [ -n "$connected_devices" ]; then
            echo "デバイスが正常に接続されました。"
            return 0  # 成功した場合は関数を終了
        else
            echo "デバイスの接続が失敗しました。再試行します。"
            retry_count=$((retry_count + 1))
            sleep 2  # 一定時間待ってから再試行
        fi
    done

    echo "デバイスの接続が $max_retries 回試行しても失敗しました。"
    exit 1
}

function pair_device {
    local device_mac=$1
    local max_retries=3
    local retry_count=0

    while [ "$retry_count" -lt "$max_retries" ]; do
        read -p "このデバイスに対してピンコードを使用しますか？ (y/n): " use_pin
        if [ "$use_pin" == "y" ]; then
            read -p "ピンコードを入力してください: " pin_code
            result=$(bluetoothctl pair "$device_mac" "$pin_code" | grep "Paired: yes")
        else
            result=$(bluetoothctl pair "$device_mac" | grep "Paired: yes")
        fi

        if [ -n "$result" ]; then
            echo "ペアリングが成功しました。"
            trust_device "$device_mac"
            connect_device "$device_mac"
            return 0  # 成功した場合は関数を終了
        else
            echo "ペアリングが失敗しました。再試行します。"
            retry_count=$((retry_count + 1))
            sleep 2  # 一定時間待ってから再試行
        fi
    done

    echo "デバイスのペアリングが $max_retries 回試行しても失敗しました。"
    exit 1
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
            device_number=""
            echo "デバイスの検索中・・・"
            search_devices
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
            device_number=""
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
