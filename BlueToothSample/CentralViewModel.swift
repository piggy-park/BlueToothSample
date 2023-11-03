//
//  CentralViewModel.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import CoreBluetooth
import Combine
import OSLog

final class CentralViewModel: NSObject, ObservableObject {
    @Published var peripheralList: [CBPeripheral] = []
    var centralManager: CBCentralManager?

    var discoveredPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
    var writeIterationsComplete = 0
    var connectionIterationsComplete = 0

    private var writeType: CBCharacteristicWriteType = .withoutResponse

    let defaultIterations = 5     // change this value based on test usecase

    var data = Data()

    func setCentralManager() {
        self.centralManager = .init(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    private func retrievePeripheral() {
        // 기존에 이미 연결된 Peripheral의 service인지 확인 후 연결
        let connectedPeripherals: [CBPeripheral] = (centralManager?.retrieveConnectedPeripherals(withServices: [BlueToothInfo.serviceUUID]))!

        blueToothLog("Found connected Peripherals with transfer service:\(connectedPeripherals)")

        if let connectedPeripheral = connectedPeripherals.last {
            blueToothLog("Connecting to peripheral\(connectedPeripheral)")
            self.discoveredPeripheral = connectedPeripheral
            centralManager?.connect(connectedPeripheral, options: nil)

            peripheralList.append(connectedPeripheral)

        } else {
            // 만약 찾지 못했다면 scan 시작
            blueToothLog("Scanning start")
            centralManager?.scanForPeripherals(withServices: [BlueToothInfo.serviceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    func stop() {
        blueToothLog("Scanning stopped")
        centralManager?.stopScan()
        data.removeAll(keepingCapacity: false)
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

    /*
     *  Write some test data to peripheral
     */
    private func writeData() {

        guard let discoveredPeripheral = discoveredPeripheral,
                let transferCharacteristic = transferCharacteristic
            else { return }

        // check to see if number of iterations completed and peripheral can accept more data
        while writeIterationsComplete < defaultIterations && discoveredPeripheral.canSendWriteWithoutResponse {

            let mtu = discoveredPeripheral.maximumWriteValueLength (for: .withoutResponse)
            var rawPacket = [UInt8]()

            let bytesToCopy: size_t = min(mtu, data.count)
            data.copyBytes(to: &rawPacket, count: bytesToCopy)
            let packetData = Data(bytes: &rawPacket, count: bytesToCopy)

            let stringFromData = String(data: packetData, encoding: .utf8)
            blueToothLog("Writing \(bytesToCopy) bytes: \(String(describing: stringFromData))")

            discoveredPeripheral.writeValue(packetData, for: transferCharacteristic, type: .withoutResponse)

            writeIterationsComplete += 1

        }

        if writeIterationsComplete == defaultIterations {
            // Cancel our subscription to the characteristic
            discoveredPeripheral.setNotifyValue(false, for: transferCharacteristic)
        }
    }
}

extension CentralViewModel: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            blueToothLog("CBManager state is unknown")
        case .resetting:
            blueToothLog("CBManager is resetting")
        case .unsupported:
            blueToothLog("Bluetooth is not supported on this device")
        case .unauthorized:
            switch CBManager.authorization {
            case .denied:
                blueToothLog("You are not authorized to use Bluetooth")
            case .restricted:
                blueToothLog("Bluetooth is restricted")
            default:
                blueToothLog("Unexpected authorization")
            }
        case .poweredOff:
            blueToothLog("CBManager is not powered on")
        case .poweredOn:
            blueToothLog("CBManager is powered on")
            retrievePeripheral()
        @unknown default:
            blueToothLog("A previously unknown central manager state occurred")
        }
    }

    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {

        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard RSSI.doubleValue >= -50
            else {
            blueToothLog("Discovered perhiperal not in expected range, at \(RSSI.intValue)", RSSI.intValue)
                return
        }
        blueToothLog("Discovered \(String(describing: peripheral.name)) at \(RSSI.intValue)")

        // Device is in range - have we already seen it?
        if discoveredPeripheral != peripheral {

            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
            discoveredPeripheral = peripheral

            // And finally, connect to the peripheral.
            blueToothLog("Connecting to perhiperal \(peripheral)")
            centralManager?.connect(peripheral, options: nil)
        }
    }

    // 연결 실패 했을 때
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        blueToothLog("Failed to connect to \(peripheral). \(String(describing: error))")
        cleanup()
    }

    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        blueToothLog("Peripheral Connected")

        // Stop scanning
        centralManager?.stopScan()
        blueToothLog("Scanning stopped")

        // set iteration info
        connectionIterationsComplete += 1
        writeIterationsComplete = 0

        // Clear the data that we may already have
        data.removeAll(keepingCapacity: false)

        // Make sure we get the discovery callbacks
        peripheral.delegate = self

        // Search only for services that match our UUID
        peripheral.discoverServices([BlueToothInfo.serviceUUID])
    }

    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        blueToothLog("Perhiperal Disconnected")
        discoveredPeripheral = nil

        // We're disconnected, so start scanning again
        if connectionIterationsComplete < defaultIterations {
            retrievePeripheral()
        } else {
            blueToothLog("Connection iterations completed")
        }
    }


}

extension CentralViewModel: CBPeripheralDelegate {

    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {

        for service in invalidatedServices where service.uuid == BlueToothInfo.serviceUUID {
            blueToothLog("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([BlueToothInfo.serviceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            blueToothLog("Error discovering services: %s", error.localizedDescription)
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
            blueToothLog("Error discovering characteristics: \(error.localizedDescription)")
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
            blueToothLog("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        guard let characteristicData = characteristic.value,
            let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }

        blueToothLog("Received \(characteristic.accessibilityElementCount()) bytes: \(stringFromData)")

        // Have we received the end-of-message token?
        if stringFromData == "EOM" {
            // End-of-message case: show the data.
            // Dispatch the text view update to the main queue for updating the UI, because
            // we don't know which thread this method will be called back on.
            DispatchQueue.main.async() {
                self.peripheralList.append(peripheral)
            }
            // Write test data
            writeData()
        } else {
            // Otherwise, just append the data to what we have previously received.
            data.append(characteristicData)
        }
    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            blueToothLog("Error changing notification state: \(error.localizedDescription)")
            return
        }

        // Exit if it's not the transfer characteristic
        guard characteristic.uuid == BlueToothInfo.characteristicUUID else { return }

        if characteristic.isNotifying {
            // Notification has started
            blueToothLog("Notification began on \(characteristic)")
        } else {
            // Notification has stopped, so disconnect from the peripheral
            blueToothLog("Notification stopped on \(characteristic). Disconnecting")
            cleanup()
        }

    }

    /*
     *  This is called when peripheral is ready to accept more data when using write without response
     */
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        blueToothLog("Peripheral is ready, send data")
        writeData()
    }

    // writeType이 .withResponse일 때, 블루투스 기기로부터 응답이 왔을때 호출되는 함수
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) { }

    // 블루투스 기기의 신호 강도를 요청하는 peripheral.readRSSI()가 호출 하는 함수
    //  신호강도와 관련된 코드 작성
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) { }
}

extension CBPeripheral: Identifiable { }
