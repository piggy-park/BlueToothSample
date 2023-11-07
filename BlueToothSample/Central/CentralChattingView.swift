//
//  CentralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth
import OSLog

struct CentralChattingView: View {
    @ObservedObject var centralUseCase\: CentralUseCase
    @State private var chatHistory: [ChattingText] = []
    @State private var textToSend: String = ""
    @FocusState private var textfieldFoucs

    init(_ useCase: CentralUseCase) {
        self.centralUseCase = useCase
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
                TextField("텍스트를 입력해 주세요", text: $textToSend)
                    .textFieldStyle(.roundedBorder)
                    .focused($textfieldFoucs)

                Button("전송") {
                    let text = "사람2: \(textToSend)"
                    centralUseCase.send(text)
                    self.textToSend = ""
                    self.textfieldFoucs = false
                }
            }
            .padding()
        }
        .onDisappear(perform: {
            centralUseCase.stop()
        })
        .onChange(of: centralUseCase.receivedChatingText, perform: { value in
            chatHistory.append(value)
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
