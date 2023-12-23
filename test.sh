#!/bin/bash

function search_devices {
    # Bluetoothデバイスのサーチ
    sudo bluetoothctl scan on &

    # 指定した秒数待機後、scan offを実行
    sleep 10
    sudo bluetoothctl scan off && sudo bluetoothctl devices
}

function pair_selected_device {
    # デバイスの数を取得
    device_count=$(echo "$devices" | wc -l)

    # デバイスが検出されなかった場合のエラー処理
    if [ $device_count -eq 0 ]; then
        echo "エラー: Bluetoothデバイスが見つかりませんでした。"
        exit 1
    fi

    # ユーザーにデバイスを選択させる
    read -p "ペアリングしたいデバイスの番号を入力してください (1-$device_count, 0で終了): " selected_number

    # 0が入力された場合は終了
    if [ $selected_number -eq 0 ]; then
        echo "終了します。"
        exit 0
    fi

    # 選択されたデバイスのアドレスを取得
    selected_address=$(echo "$devices" | sed -n "${selected_number}p" | awk '{print $2}')

    # Bluetoothデバイスとペアリング
    sudo bluetoothctl <<EOF
power on
agent on
default-agent
pair $selected_address
EOF

    # ペアリングの結果を確認
    pairing_result=$?

    if [ $pairing_result -eq 0 ]; then
        echo "ペアリングが成功しました。"
    else
        echo "エラー: ペアリングに失敗しました。"
    fi
}

# メインの処理
devices=$(search_devices)
pair_selected_device