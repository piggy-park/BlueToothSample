//
//  PeripheralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth

struct PeripheralView: View {
    @StateObject var peripheralUseCase: PeripheralUseCase = .init()
    @State private var textToSend: String = ""
    @State private var showJoinAlert: Bool = false
    @State private var showBlueToothAuthAlert: Bool = false
    @State private var chatHistory: [ChattingText] = []

    @FocusState private var textfieldFoucs

    var body: some View {
        VStack {
            List {
                ForEach(chatHistory) { chat in
                    HStack {
                        Text(chat.text)
                        Spacer()
                        Text(Date(), style: .time)
                    }
                    .listRowSeparator(.hidden)
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
                    peripheralUseCase.send(text)
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
            peripheralUseCase.stop()
        }
        .onChange(of: peripheralUseCase.sentText, perform: {
            chatHistory.append($0)
        })
        .onChange(of: peripheralUseCase.peripheralConnectStatus, perform: { value in
            switch value {
            case .success:
                let chat = ChattingText(text: "유저가 방을 들어왔습니다.")
                chatHistory.append(chat)
            case .disconnected:
                let chat = ChattingText(text: "유저가 방을 떠났습니다.")
                chatHistory.append(chat)
            default:
                break
            }
        })
        .onChange(of: peripheralUseCase.blueToothStatus, perform: { value in
            switch value {
            case .allowedAlways:
                peripheralUseCase.start()
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
    }
}
