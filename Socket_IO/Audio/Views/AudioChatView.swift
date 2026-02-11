//
//  AudioChatView.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import SwiftUI
struct callButtonStyle:ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 20, weight: .bold, design: .default))
            .foregroundColor(.white)
            .padding()
            
            .cornerRadius(10)
    }
}



    
    
    struct AudioChatView: View {
            @Binding var roomId: String
            @ObservedObject var socketManager: SocketManagerClient
            
            @StateObject var viewModel: AudioViewModel
            @State private var isBool: Bool = false
        
        init(roomId: Binding<String>, socketManager: SocketManagerClient) {
                self._roomId = roomId
                self.socketManager = socketManager
                // Purane socketManager ko naye ViewModel mein pass kiya
                self._viewModel = StateObject(wrappedValue: AudioViewModel(socketManager: socketManager))
            }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack{
                    Text ("User1")
                        .foregroundStyle(Color.white)
                }
            }
            .overlay(
                HStack(spacing: 30) {
                    Button { } label: {
                        Image(systemName: "mic.fill")
                    }
                    .modifier(callButtonStyle())
                   

                    Button { } label: {
                        Image(systemName: "phone.down.fill")
                    }
                    .modifier(callButtonStyle())

                    Button { } label: {
                        Image(systemName: "speaker.fill")
                    }
                    .modifier(callButtonStyle())
                }
                .padding(.bottom, 40),
                alignment: .bottom
            )
            .onAppear {
                isBool.toggle()
               
            }
            .alert("Do you want to switch to Audio Call?", isPresented: $isBool) {
                Button("Confirm", role: .cancel) {
                    viewModel.checkPermissions()
                    viewModel.startLocalAudioCapture()
                    viewModel.startCall(roomId: roomId)
             
                    
                    
                    
                    
                    
                }
                Button("Cancel", role: .destructive) {}
            }
        }
    }



