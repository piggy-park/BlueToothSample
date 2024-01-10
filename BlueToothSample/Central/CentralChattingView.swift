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
    @ObservedObject var centralUseCase: CentralUseCase
    @State private var chatHistory: [ChattingText] = []
    @State private var textToSend: String = ""
    @FocusState private var textfieldFoucs
    private let userName: String

    init(_ useCase: CentralUseCase, userName: String) {
        self.centralUseCase = useCase
        self.userName = userName
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
                    let text = "\(userName): \(textToSend)"
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
        .onChange(of: centralUseCase.connectStatus, perform: { value in
            switch value {
            case .success:
                blueToothLog(deviceType: .central, "연결 성공")
            case .subscribe:
                blueToothLog(deviceType: .central, "채팅 시작")
                centralUseCase.send("\(userName)님이 방에 입장했습니다.")
            case .fail:
                blueToothLog(deviceType: .central, "방 입장에 실패했습니다.")
                let chat = ChattingText(text: "방 입장에 실패했습니다.")
                chatHistory.append(chat)
            case .disconnected:
                blueToothLog(deviceType: .central, "연결이 끊어졌습니다.")
                let chat = ChattingText(text: "연결이 끊어졌습니다.")
                chatHistory.append(chat)
            default:
                break
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
