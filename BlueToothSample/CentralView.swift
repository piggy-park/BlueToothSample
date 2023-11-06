//
//  CentralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth
import OSLog

struct CentralView: View {
    @ObservedObject var viewModel: CentralViewModel = .init()
    @State private var showBlueToothAuthAlert: Bool = false

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
        .alert("블루투스 권한이 필요합니다", isPresented: $showBlueToothAuthAlert, actions: {
            Button("취소", role: .cancel) { 
                self.showBlueToothAuthAlert = false
            }
            Button("설정") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        })
        .onDisappear(perform: {
            viewModel.stop()
        })
        .onChange(of: viewModel.blueToothStatus, perform: { value in
            switch value {
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog("Unexpected authorization")
            }
        })
    }
}
