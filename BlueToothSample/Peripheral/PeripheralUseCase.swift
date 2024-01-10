//
//  PeripheralViewModel.swift
//  BlueToothSample
//
//  Created by gx_piggy on 11/3/23.
//

import OSLog
import CoreBluetooth

enum PeripheralConnectStatus {
    case none
    case success
    case fail
    case disconnected(userName: String)
}

extension PeripheralConnectStatus: Equatable { }

final class PeripheralUseCase: NSObject, ObservableObject {
    @Published var blueToothStatus: CBManagerAuthorization = .notDetermined
    @Published var sentText: ChattingText = .init(text: "")
    @Published var peripheralConnectStatus: PeripheralConnectStatus = .none

    private var connectedUserDic: [CBCentral: String] = [:]
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    private var lastConnectedCentral: CBCentral?
    private var dataToSend = Data()
    private var sendDataIndex: Int = 0
    private var sendText: String = ""
    private var sendingEOM = false
    private let roomName: String = ""

    override init() {
        super.init()
        setPeripheralManager()
    }

    func setPeripheralManager() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }

    func start(roomName: String) {
        blueToothLog(deviceType: .periphearl, "start advertising \(roomName)")
        peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [BlueToothInfo.serviceUUID],
                                                CBAdvertisementDataLocalNameKey: roomName]) // 채팅방 이름
    }

    func stop() {
        blueToothLog(deviceType: .periphearl, "stop advertising")
        peripheralManager?.stopAdvertising()
    }
    // MARK: - Helper Methods

    /*
     *  Sends the next amount of data to the connected central
     */
    private func sendData() {
        guard let transferCharacteristic = transferCharacteristic,
              let peripheralManager = peripheralManager else { return }

        // 보낼 마지막 메세지(EOM) 여부 Flag확인
        if sendingEOM {
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            // EOM 보내기 성공시
            if didSend {
                sendingEOM = false
                self.sentText = .init(text: sendText)
                blueToothLog(deviceType: .periphearl, "Sent: EOM")
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
            if let mtu = lastConnectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }

            // 필요한 만큼 데이터 잘라서 카피
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            // Send
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)

            // 만약 데이터 전송에 실패한다면 리턴 후 call back 기다림
            if !didSend { return }

            let stringFromData = String(data: chunk, encoding: .utf8)
            blueToothLog(deviceType: .periphearl, "Sent \(chunk.count) bytes: \(String(describing: stringFromData))")

            // 보내기 성공시 data index 변경
            sendDataIndex += amountToSend
            // 마지막으로 보낼 data 일경우
            // EOM Flag 보냄
            if sendDataIndex >= dataToSend.count {
                sendingEOM = true

                // EOM Send it
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                            for: transferCharacteristic, onSubscribedCentrals: nil)
                // 성공시
                if eomSent {
                    self.sentText = .init(text: sendText)
                    // It sent; we're all done
                    sendingEOM = false
                    blueToothLog(deviceType: .periphearl, "Sent: EOM")
                }
                return
            }
        }
    }

    func send(_ text: String) {
        self.sendText = text
        dataToSend = sendText.data(using: .utf8) ?? Data()
        // Reset the index
        sendDataIndex = 0
        sendData()
    }

    private func setupPeripheral() {
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: BlueToothInfo.characteristicUUID,
                                                             properties: [.writeWithoutResponse, .notify],
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

extension PeripheralUseCase: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        switch peripheral.state {
        case .poweredOn:
            blueToothLog(deviceType: .periphearl, "CBManager is powered on")
            setupPeripheral()
        case .poweredOff:
            blueToothLog(deviceType: .periphearl, "CBManager is not powered on")
            stop()
        case .resetting:
            blueToothLog(deviceType: .periphearl, "CBManager is resetting")
        case .unauthorized:
            self.blueToothStatus =  CBManager.authorization
        case .unknown:
            blueToothLog(deviceType: .periphearl, "CBManager state is unknown")
        case .unsupported:
            blueToothLog(deviceType: .periphearl, "Bluetooth is not supported on this device")
        @unknown default:
            blueToothLog(deviceType: .periphearl, "A previously unknown peripheral manager state occurred")
        }
    }

    /*
     *  Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        blueToothLog(deviceType: .periphearl, "Central subscribed to characteristic")
        // save central
        lastConnectedCentral = central
        self.peripheralConnectStatus = .success
    }

    /*
     *  Recognize when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        blueToothLog(deviceType: .periphearl, "Central unsubscribed from characteristic")
        lastConnectedCentral = nil
        let unsubscribedUserName = connectedUserDic[central]
        connectedUserDic.removeValue(forKey: central)
        self.peripheralConnectStatus = .disconnected(userName: unsubscribedUserName ?? "")
    }

    //  현재 큐에 자리가 없어서 전송에 실패했을 경우, 준비가 되면 그때 다시 send함.
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        blueToothLog(deviceType: .periphearl, "send another chunk data Byte:\(dataToSend.count)")
        sendData()
    }

    // 값 수정시 호출됨.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {

        for aRequest in requests {
            guard let requestValue = aRequest.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8),
                  let userName = stringFromData.split(separator: "님").first else { continue }
            if stringFromData != "EOM" {
                let central = aRequest.central
                connectedUserDic[central] = String(userName)

                blueToothLog(deviceType: .periphearl, "Received write request of \(requestValue.count) bytes: \(stringFromData) from \(userName)")

                send(stringFromData)
            }
        }
    }
}
