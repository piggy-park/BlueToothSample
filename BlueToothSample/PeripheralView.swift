//
//  PeripheralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth

struct PeripheralView: View {
    @ObservedObject var viewModel: PeripheralViewModel = .init()
    @State private var sendText: String = ""
    @State private var showJoinAlert: Bool = false
    @State private var showBlueToothAuthAlert: Bool = false

    var body: some View {
        VStack {
            TextField("input text", text: $sendText)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("send text") {
                viewModel.start()
                viewModel.sendText = sendText
            }
        }
        .padding()
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
        .onDisappear {
            viewModel.stop()
        }
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
