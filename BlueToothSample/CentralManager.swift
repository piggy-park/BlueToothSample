//
//  CentralViewModel.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import CoreBluetooth
import Combine
import OSLog

final class CentralManager: NSObject, ObservableObject {
    @Published var peripheralList: [CBPeripheral] = []
    @Published var blueToothStatus: CBManagerAuthorization = .notDetermined
    @Published var receivedChatingText: ChattingText = .init(text: "")
    var centralManager: CBCentralManager?

    var discoveredPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    var receivedData = Data()
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    var sendingEOM = false

    override init() {
        super.init()
        setCentralManager()
    }

    func setCentralManager() {
        self.centralManager = .init(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func connect(_ peripheral: CBPeripheral) {
        centralManager?.connect(peripheral, options: nil)
        discoveredPeripheral = peripheral
        blueToothLog(deviceType: .central, "Connecting to perhiperal \(peripheral)")
    }

    private func retrievePeripheral() {
        guard let centralManager =  centralManager else { return }
        // 기존에 이미 연결된 Peripheral의 service들 확인
        let connectedPeripherals: [CBPeripheral] = centralManager.retrieveConnectedPeripherals(withServices: [BlueToothInfo.serviceUUID])
        blueToothLog(deviceType: .central, "Found connected Peripherals with transfer service:\(connectedPeripherals)")

        peripheralList = connectedPeripherals
        // scan 시작
        // centralManager(_:didDiscover:advertisementData:rssi:) call
        blueToothLog(deviceType: .central,"Scanning start")
        centralManager.scanForPeripherals(withServices: [BlueToothInfo.serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

    }

    func stop() {
        blueToothLog(deviceType: .central,"Scanning stopped")
        centralManager?.stopScan()
        receivedData.removeAll(keepingCapacity: false)
    }

    /*
     *  Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup() {
        // Don't do anything if we're not connected
        guard let discoveredPeripheral = discoveredPeripheral,
              case .connected = discoveredPeripheral.state else { return }

        for service in (discoveredPeripheral.services ?? [] as [CBService]) {
            for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                if characteristic.uuid == BlueToothInfo.characteristicUUID && characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                }
            }
        }

        // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager?.cancelPeripheralConnection(discoveredPeripheral)
        peripheralList.removeAll()
    }

    func send(_ text: String) {
        self.dataToSend = text.data(using: .utf8) ?? Data()
        sendDataIndex = 0
        writeData()
    }

    /*
     *  Write some test data to peripheral
     */
    private func writeData() {

        guard let discoveredPeripheral = discoveredPeripheral,
              let transferCharacteristic = transferCharacteristic
        else { return }

        if sendingEOM {
            discoveredPeripheral.writeValue("EOM".data(using: .utf8)!, for: transferCharacteristic, type: writeType)
            blueToothLog(deviceType: .central, "Sent: EOM")
            sendingEOM = false
            return
        }

        if sendDataIndex >= dataToSend.count {
            return
        }

        while true {
            // TODO: -- 전송후 에러 처리 해야함.
            var amountToSend = dataToSend.count - sendDataIndex
            let mtu = discoveredPeripheral.maximumWriteValueLength (for: writeType)
            amountToSend = min(amountToSend, mtu)

            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))

            let stringFromData = String(data: chunk, encoding: .utf8)
            blueToothLog(deviceType: .central, "Writing \(chunk.count) bytes: \(String(describing: stringFromData))")

            discoveredPeripheral.writeValue(chunk, for: transferCharacteristic, type: writeType)
            sendDataIndex += amountToSend
            if sendDataIndex >= dataToSend.count {
                discoveredPeripheral.writeValue("EOM".data(using: .utf8)!, for: transferCharacteristic, type: writeType)
                self.sendingEOM = true
                blueToothLog(deviceType: .central, "Sent: EOM")
                return
            }
        }
    }
}

extension CentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            blueToothLog(deviceType: .central, "CBManager state is unknown")
        case .resetting:
            blueToothLog(deviceType: .central, "CBManager is resetting")
        case .unsupported:
            blueToothLog(deviceType: .central, "Bluetooth is not supported on this device")
        case .unauthorized:
            self.blueToothStatus = CBManager.authorization
        case .poweredOff:
            blueToothLog(deviceType: .central, "CBManager is not powered on")
        case .poweredOn:
            blueToothLog(deviceType: .central, "CBManager is powered on")
            retrievePeripheral()
        @unknown default:
            blueToothLog(deviceType: .central, "A previously unknown central manager state occurred")
        }
    }

    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        blueToothLog(deviceType: .central, "Discovered \(String(describing: peripheral.name)) at \(RSSI.intValue)")
        // 서치된 peripheral들이 list에 없던 놈이라면 추가
        if !peripheralList.contains(peripheral) {
            peripheralList.append(peripheral)
        }
    }

    // 연결 실패 했을 때
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        blueToothLog(deviceType: .central, "Failed to connect to \(peripheral). \(String(describing: error))")
        cleanup()
    }

    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        blueToothLog(deviceType: .central, "Peripheral Connected")

        // Stop scanning
        centralManager?.stopScan()
        blueToothLog(deviceType: .central, "Scanning stopped")

        // Clear the data that we may already have
        receivedData.removeAll(keepingCapacity: false)

        // Make sure we get the discovery callbacks
        peripheral.delegate = self

        // Search only for services that match our UUID
        peripheral.discoverServices([BlueToothInfo.serviceUUID])
    }

    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        blueToothLog(deviceType: .central, "Perhiperal Disconnected")
        discoveredPeripheral = nil

        // We're disconnected, so start scanning again
        retrievePeripheral()
    }
}

extension CentralManager: CBPeripheralDelegate {

    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {

        for service in invalidatedServices where service.uuid == BlueToothInfo.serviceUUID {
            blueToothLog(deviceType: .central, "Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([BlueToothInfo.serviceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            blueToothLog(deviceType: .central, "Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }

        // Discover the characteristic we want...

        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([BlueToothInfo.characteristicUUID], for: service)
        }
    }

    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            blueToothLog(deviceType: .central, "Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where characteristic.uuid == BlueToothInfo.characteristicUUID {
            // If it is, subscribe to it
            transferCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }

        // Once this is complete, we just need to wait for the data to come in.
    }

    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            blueToothLog(deviceType: .central, "Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }

        blueToothLog(deviceType: .central, "Received \(characteristic.accessibilityElementCount()) bytes: \(stringFromData)")

        // Have we received the end-of-message token?
        if stringFromData == "EOM" {
            let text = String(data: self.receivedData, encoding: .utf8) ?? ""
            self.receivedChatingText = ChattingText(text: text)
            self.receivedData.removeAll()
        } else {
            // Otherwise, just append the data to what we have previously received.
            receivedData.append(characteristicData)
        }
    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            blueToothLog(deviceType: .central, "Error changing notification state: \(error.localizedDescription)")
            return
        }

        // Exit if it's not the transfer characteristic
        guard characteristic.uuid == BlueToothInfo.characteristicUUID else { return }

        if characteristic.isNotifying {
            // Notification has started
            blueToothLog(deviceType: .central, "Notification began on \(characteristic)")
        } else {
            // Notification has stopped, so disconnect from the peripheral
            blueToothLog(deviceType: .central, "Notification stopped on \(characteristic). Disconnecting")
            cleanup()
        }

    }

    /*
     *  This is called when peripheral is ready to accept more data when using write without response
     */
        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            blueToothLog(deviceType: .central, "Peripheral is ready, send data")
            writeData()
        }

    // writeType이 .withResponse일 때, 블루투스 기기로부터 응답이 왔을때 호출되는 함수
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        blueToothLog(deviceType: .central, "write value error: \(String(describing: error?.localizedDescription))")
    }

    // 블루투스 기기의 신호 강도를 요청하는 peripheral.readRSSI()가 호출 하는 함수
    //  신호강도와 관련된 코드 작성
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) { }
}

extension CBPeripheral: Identifiable { }
