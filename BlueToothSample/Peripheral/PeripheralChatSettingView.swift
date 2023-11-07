//
//  PeripheralChatSettingView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 11/7/23.
//

import Foundation
import SwiftUI

struct PeripheralChatSettingView: View {
    @StateObject var peripheralUseCase: PeripheralUseCase = .init()
    @State private var showBlueToothAuthAlert: Bool = false
    @State private var goToChattingRoom: Bool = false
    @State private var inputRoomName: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("방 이름", text: $inputRoomName)
                .textFieldStyle(.roundedBorder)
                .padding()
            Button("방 만들기") {
                self.goToChattingRoom = true
            }
            .buttonStyle(.bordered)
            .disabled(inputRoomName.isEmpty ? true : false)
        }
        .onChange(of: peripheralUseCase.blueToothStatus, perform: { value in
            switch value {
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
        .background {
            NavigationLink(isActive: $goToChattingRoom) {
                PeripheralChattingView(peripheralUseCase)
                    .onAppear {
                        peripheralUseCase.start(roomName: inputRoomName)
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
    }
}
