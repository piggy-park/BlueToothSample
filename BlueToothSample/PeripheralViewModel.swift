//
//  PeripheralViewModel.swift
//  BlueToothSample
//
//  Created by gx_piggy on 11/3/23.
//

import OSLog
import CoreBluetooth

final class PeripheralViewModel: NSObject, ObservableObject {
    @Published var blueToothStatus: CBManagerAuthorization = .notDetermined

    private var peripheralManager: CBPeripheralManager?
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    var sendMessageButtonTapped: Bool = false
    var sendText: String = ""
    private var sendingEOM = false

    override init() {
        super.init()
        setPeripheralManager()
    }

    func setPeripheralManager() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }

    func start() {
        blueToothLog("start advertising")
        peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [BlueToothInfo.serviceUUID]])
    }

    func stop() {
        blueToothLog("stop advertising")
        peripheralManager?.stopAdvertising()
    }
    // MARK: - Helper Methods

    /*
     *  Sends the next amount of data to the connected central
     */
    private func sendData() {
        guard let transferCharacteristic = transferCharacteristic else { return }
        // 보낼 마지막 메세지(EOM) 여부 Flag확인
        if sendingEOM {
            guard let didSend = peripheralManager?.updateValue("EOM".data(using: .utf8) ?? Data(), for: transferCharacteristic, onSubscribedCentrals: nil) else { return }
            // EOM 보내기 성공시
            if didSend {
                sendingEOM = false
                blueToothLog("Sent: EOM")
            }
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }

        // MARK: -- SendingEOM을 보내지 않았을 경우.

        // 남은 데이터 없음
        if sendDataIndex >= dataToSend.count {
            return
        }

        // 보낼 데이터가 남았음.
        var didSend = true
        // callback이 실패하거나 전송이 끝날 때 까지 계속
        while didSend {
            var amountToSend = dataToSend.count - sendDataIndex
            // 연결된 central이 받을 수 있는 최대 양 비교
            
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }

            // 필요한 만큼 데이터 잘라서 카피
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            // Send
            didSend = ((peripheralManager?.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)) != nil)

            // 만약 데이터 전송에 실패한다면 리턴 후 call back 기다림
            if !didSend { return }

            let stringFromData = String(data: chunk, encoding: .utf8)
            blueToothLog("Sent \(chunk.count) bytes: \(String(describing: stringFromData))")

            // 보내기 성공시 data index 변경
            sendDataIndex += amountToSend
            // 마지막으로 보낼 data 일경우
            // EOM Flag 보냄
            if sendDataIndex >= dataToSend.count {
                sendingEOM = true

                // EOM Send it
                let eomSent = peripheralManager?.updateValue("EOM".data(using: .utf8) ?? Data(),
                                                             for: transferCharacteristic, onSubscribedCentrals: nil)
                // 성공시
                if eomSent ?? false {
                    // It sent; we're all done
                    sendingEOM = false
                    blueToothLog("Sent: EOM")
                }
                return
            }
        }
    }

    private func setupPeripheral() {
        // build service

        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: BlueToothInfo.characteristicUUID,
                                                         properties: [.notify, .writeWithoutResponse],
                                                         value: nil,
                                                         permissions: [.readable, .writeable])

        // Create a service from the characteristic.
        let transferService = CBMutableService(type: BlueToothInfo.serviceUUID, primary: true)

        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]

        // And add it to the peripheral manager.
        peripheralManager?.add(transferService)

        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic
    }
}

extension PeripheralViewModel: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        switch peripheral.state {
        case .poweredOn:
            blueToothLog("CBManager is powered on")
            setupPeripheral()
        case .poweredOff:
            blueToothLog("CBManager is not powered on")
        case .resetting:
            blueToothLog("CBManager is resetting")
        case .unauthorized:
            self.blueToothStatus =  CBManager.authorization
        case .unknown:
            blueToothLog("CBManager state is unknown")
        case .unsupported:
            blueToothLog("Bluetooth is not supported on this device")
        @unknown default:
            blueToothLog("A previously unknown peripheral manager state occurred")
        }
    }

    /*
     *  Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        blueToothLog("Central subscribed to characteristic")

        dataToSend = sendText.data(using: .utf8) ?? Data()
        // Reset the index
        sendDataIndex = 0

        // save central
        connectedCentral = central

        // Start sending
        sendData()
    }

    /*
     *  Recognize when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        blueToothLog("Central unsubscribed from characteristic")
        connectedCentral = nil
        stop()
    }

    /*
     *  This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        blueToothLog("send another chunk data Byte:\(dataToSend.count)")
        // Start sending again
        sendData()
    }

    /*
     * This callback comes in when the PeripheralManager received write to characteristics
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                let stringFromData = String(data: requestValue, encoding: .utf8) else {
                    continue
            }

            blueToothLog("Received write request of \(requestValue.count) bytes: \(stringFromData)")
        }
    }
}
