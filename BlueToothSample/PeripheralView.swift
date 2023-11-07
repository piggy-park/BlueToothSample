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
    @State private var textToSend: String = ""
    @State private var showJoinAlert: Bool = false
    @State private var showBlueToothAuthAlert: Bool = false
    @State private var chatHistory: [ChattingText] = []
    @FocusState private var textfieldFoucs

    var body: some View {
        VStack {
            Text("Periphearl View")
            List {
                ForEach(chatHistory) {
                    Text($0.text)
                }
            }
            .listStyle(.plain)

            HStack {
                TextField("input text", text: $textToSend)
                    .textFieldStyle(.roundedBorder)
                    .focused($textfieldFoucs)
                    .padding()

                Button("send text") {
                    let text = "사람1: \(textToSend)"
                    viewModel.send(text)
                    self.textToSend = ""
                    self.textfieldFoucs = false
                }
            }
            .padding()
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
        .onChange(of: viewModel.sentText, perform: {
            chatHistory.append($0)
        })
        .onChange(of: viewModel.blueToothStatus, perform: { value in
            switch value {
            case .allowedAlways:
                viewModel.start()
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
    }
}
