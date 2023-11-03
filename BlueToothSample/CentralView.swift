//
//  CentralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth
import os

class BlueToothLog: OSLog {

}

// static string을 우회하기 위해 arg를 message로 수정
func blueToothLog(log: OSLog = .default, type: OSLogType = .default, _ message: CVarArg...) {
    os_log(type, log: log, "%@", "BlueTooth: \(message)")
}

struct CentralView: View {
    @ObservedObject var viewModel: CentralViewModel = .init()
    @State private var showAlert: Bool = false

    var body: some View {
        List {
            Text("Central View")
            Button("stop") {
                viewModel.stop()
            }
            Section {
                ForEach(viewModel.peripheralList) { item in
                    Button(action: {
//                        viewModel.connect(item)
                    }, label: {
                        Text("\(item.name ?? "hi")")
                    })
                }
            } header: {
                HStack {
                    Text("연결 가능 기기")
                        .bold()
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("블루투스 권한 설정"), message: Text("블루투스 기능을 이용하기 위해 설정을 변경해주세요"), primaryButton: .default(Text("설정"), action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }), secondaryButton: .default(Text("취소")))
        }
        .onAppear {
            viewModel.setCentralManager()
        }
        .onDisappear(perform: {
            viewModel.stop()
        })
    }
}
