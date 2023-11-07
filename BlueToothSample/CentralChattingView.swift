//
//  CentralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth
import OSLog


struct ChattingListView: View {
    @StateObject var centralMananger: CentralManager = .init()
    @State private var showConnectAlert: Bool = false
    @State private var selectedPeripheral: CBPeripheral?
    @State private var showBlueToothAuthAlert: Bool = false
    @State private var goToChattingRoom: Bool = false

    var body: some View {
        List {
            ForEach(centralMananger.peripheralList) { peripheral in
                Button(peripheral.name ?? "알수 없는 기기") {
                    self.showConnectAlert = true
                    self.selectedPeripheral = peripheral
                }
            }
        }
        .alert("채팅방에 입장하시겠습니까?", isPresented: $showConnectAlert) {
            Button("취소", role: .cancel) { }
            Button("확인") { self.goToChattingRoom = true }
        }
        .background {
            NavigationLink(isActive: $goToChattingRoom) {
                LazyView {
                    CentralChattingView(viewModel: centralMananger)
                    // TODO: 연결 안되면 에러처리
                        .onAppear {
                            if let selectedPeripheral {
                                centralMananger.connect(selectedPeripheral)
                            }
                        }
                }
            } label: {
                EmptyView()
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
        .onChange(of: centralMananger.blueToothStatus, perform: { value in
            switch value {
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
    }
}


struct CentralChattingView: View {
    @ObservedObject var viewModel: CentralManager
    @State private var chatHistory: [ChattingText] = []
    @State private var textToSend: String = ""
    @FocusState private var textfieldFoucs

    init(viewModel: CentralManager) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Text("Central View")
            List {
                ForEach(chatHistory) {
                    Text($0.text)
                }
            }
            .listStyle(.plain)
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
