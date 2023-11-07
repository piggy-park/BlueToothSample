//
//  PeripheralChattingView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth

struct PeripheralChattingView: View {
    @ObservedObject var peripheralUseCase: PeripheralUseCase
    @State private var textToSend: String = ""
    @State private var chatHistory: [ChattingText] = []
    @FocusState private var textfieldFoucs

    init(_ useCase: PeripheralUseCase) {
        self.peripheralUseCase = useCase
    }

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
    }
}
