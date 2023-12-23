#!/bin/bash

function show_devices {
    # Bluetoothデバイスの検出
    devices=$(sudo bluetoothctl devices)

    # 検出されたデバイスのリストを表示
    echo "検出されたBluetoothデバイス:"
    echo "$devices"
}

function show_paired_devices {
    # Bluetoothデバイスの検出（ペアリングされているデバイスのみ）
    paired_devices=$(sudo bluetoothctl paired-devices)

    # 検出されたペアリングされているデバイスのリストを表示
    echo "ペアリングされているBluetoothデバイス:"
    echo "$paired_devices"
}

function pair_device {
    # Bluetoothデバイスの検出
    devices=$(sudo bluetoothctl devices)

    # 検出されたデバイスのリストを表示
    echo "検出されたBluetoothデバイス:"
    echo "$devices"

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

    # ピンコードの有無を確認
    read -p "BluetoothデバイスにPINコードが必要ですか？ (y/n): " need_pin

    if [ "$need_pin" == "y" ]; then
        # PINコードの入力を求める
        read -p "BluetoothデバイスのPINコードを入力してください: " pin_code

        # Bluetoothデバイスとペアリング
        sudo bluetoothctl <<EOF
power on
agent on
default-agent
pair $selected_address
$pin_code
EOF
    else
        # Bluetoothデバイスとペアリング（PINコードの入力なし）
        sudo bluetoothctl <<EOF
power on
agent on
default-agent
pair $selected_address
EOF
    fi

    # ペアリングの結果を確認
    pairing_result=$?

    if [ $pairing_result -eq 0 ]; then
        echo "ペアリングが成功しました。"
    else
        echo "エラー: ペアリングに失敗しました。"
    fi
}

function remove_device {
    show_paired_devices

    # デバイスの数を取得
    device_count=$(echo "$paired_devices" | wc -l)

    # デバイスが検出されなかった場合のエラー処理
    if [ $device_count -eq 0 ]; then
        echo "エラー: ペアリングされているBluetoothデバイスが見つかりませんでした。"
        exit 1
    fi

    # ユーザーにデバイスを選択させる
    read -p "削除したいデバイスの番号を入力してください (1-$device_count, 0で終了): " selected_number

    # 0が入力された場合は終了
    if [ $selected_number -eq 0 ]; then
        echo "終了します。"
        exit 0
    fi

    # 選択されたデバイスのアドレスを取得

    selected_address=$(echo "$paired_devices" | sed -n "${selected_number}p" | awk '{print $2}')

    # Bluetoothデバイスのペアリングを解除
    sudo bluetoothctl <<EOF
remove $selected_address
EOF

    # ペアリング解除の結果を確認
    remove_result=$?

    if [ $remove_result -eq 0 ]; then
        echo "デバイスのペアリングが解除されました。"
    else
        echo "エラー: デバイスのペアリング解除に失敗しました。"
    fi
}

# メインの処理
# ユーザーにアクションを選択させる
read -p "1: ペアリング, 2: ペアリング解除, 0: 終了 を入力してください: " action

case $action in
    1)
        pair_device
        ;;
    2)
        remove_device
        ;;
    0)
        echo "終了します。"
        ;;
    *)
        echo "エラー: 不正な入力です。"
        ;;
esac