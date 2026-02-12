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
            @Binding var selectedTab: Int
            
            @StateObject var viewModel: AudioViewModel
            @State private var isBool: Bool = false
            @Environment(\.dismiss) private var dismiss
     
        init(roomId: Binding<String>, socketManager: SocketManagerClient,selectedTab: Binding<Int>) {
                self._roomId = roomId
                self.socketManager = socketManager
            self._selectedTab = selectedTab
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
                    Button {
                            viewModel.toggleMute()
                        } label: {
                            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                                .foregroundColor(viewModel.isMuted ? .red : .white)
                        }
                        .modifier(callButtonStyle())
                   

                    Button {
                        if !viewModel.isCallActive {
                                    
                                            viewModel.startCall(roomId: roomId)
                            viewModel.isCallActive = true
                                        } else {
                                          
                                            viewModel.hangup()
                                            
                                        }
                                    } label: {
                                        Image(systemName: viewModel.isCallActive ? "phone.down.fill" : "phone.fill")
                                            .font(.system(size: 30))
                                            .padding(20)
                                            .background(viewModel.isCallActive ? Color.red : Color.green)
                                            .clipShape(Circle())
                                            .foregroundColor(.white)
                                    }
                    Button {
                            viewModel.toggleSpeaker()
                        } label: {
                            Image(systemName: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                                .foregroundColor(viewModel.isSpeakerOn ? .blue : .white)
                        }
                        .modifier(callButtonStyle())
                    
                }
                .padding(.bottom, 40),
                alignment: .bottom
            )
            .onAppear {
                isBool = true
                socketManager.joinRoom(id: roomId)
                
            
                socketManager.listenForEndCall {
                    DispatchQueue.main.async {
                        viewModel.isCallActive = false
                        // Connection bhi clean kar dein bina socket emit kiye
                        viewModel.hangup()
                        print("✅ UI Reset because other user ended call")
                    }
                }
            }
            .alert("Do you want to switch to Audio Call?", isPresented: $isBool) {
                Button("Confirm", role: .cancel) {
                    viewModel.checkPermissions()
                    viewModel.startLocalAudioCapture()
                   

                }
                Button("Cancel", role: .destructive) {
                    viewModel.hangup()
                    selectedTab = 0
                }
            }
            .onDisappear {
                print("👋 Cleaning up...")
                viewModel.hangup()
                viewModel.isCallActive = false // State reset for next time
                isBool = false       // Alert state reset
            }        }
    }

