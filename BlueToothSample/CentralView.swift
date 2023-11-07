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
    @State private var chatHistory: [ChattingText] = []
    @State private var textToSend: String = ""
    @FocusState private var textfieldFoucs

    var body: some View {
        VStack {
            Text("Central View")
            List {
                ForEach(chatHistory) {
                    Text($0.text)
                }
            }
            .listStyle(.plain)
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
            HStack {
                TextField("텍스트를 입력해 주세요", text: $textToSend)
                    .textFieldStyle(.roundedBorder)
                    .focused($textfieldFoucs)

                Button("전송") {
                    let text = "사람2: \(textToSend)"
                    viewModel.send(text)
                    self.textToSend = ""
                    self.textfieldFoucs = false
                }
            }
            .padding()
        }
        .onDisappear(perform: {
            viewModel.stop()
        })
        .onChange(of: viewModel.receivedChatingText, perform: { value in
            chatHistory.append(value)
        })
        .onChange(of: viewModel.blueToothStatus, perform: { value in
            switch value {
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
    }
}

struct ChattingText: Identifiable {
    var id: String {
        return "\(date) \(text)"
    }
    let date = Date()
    let text: String
}

extension ChattingText: Equatable {
    static func == (lhs: ChattingText, rhs: ChattingText) -> Bool {
        return lhs.date.timeIntervalSince1970 == rhs.date.timeIntervalSince1970
    }
}
