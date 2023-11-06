//
//  BlueToothInfo.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import Foundation
import CoreBluetooth
import OSLog

struct BlueToothInfo {
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
}


// static string을 우회하기 위해 arg를 message로 수정
func blueToothLog(log: OSLog = .default, type: OSLogType = .default, _ message: CVarArg...) {
    os_log(type, log: log, "%@", "BlueTooth: \(message)")
}
