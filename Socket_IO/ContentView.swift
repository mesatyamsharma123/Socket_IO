import SwiftUI
import Foundation

enum ConnectionState {
    case idle
    case connected
    case enterRoom
}
struct ContentView: View {
    @StateObject private var socketManager = SocketManagerClient()
    @State private var state: ConnectionState = .idle
    @State private var messageText: String = ""
    @State private var roomID: String = ""

    var body: some View {
        VStack {
            if state == .idle {
                connectionView
            } else if state == .connected {
                roomEntryView
            } else if state == .enterRoom {
                chatRoomView
            }
        }
        .animation(.default, value: state)
    }


    private var connectionView: some View {
        VStack(spacing: 20) {
            StatusIndicator(isConnected: socketManager.isConnected)
            Button("Connect to Server") {
                socketManager.connect()
                state = .connected
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var roomEntryView: some View {
        VStack(spacing: 20) {
            TextField("Enter Room ID", text: $roomID)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button("Join Room") {
                if !roomID.isEmpty {
                    socketManager.joinRoom(id: roomID)
                    state = .enterRoom
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!socketManager.isConnected)
        }
    }

    private var chatRoomView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(socketManager.chat) { msg in
                            ChatBubble(message: msg, isMe: msg.senderID == socketManager.currentUserID)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: socketManager.chat.count) { _ in
                    withAnimation {
                        proxy.scrollTo(socketManager.chat.last?.id, anchor: .bottom)
                    }
                }
            }

          
            HStack {
                TextField("Message", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button {
                    if !messageText.isEmpty {
                        socketManager.send(message: messageText, roomId: roomID)
                        messageText = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding()
        }
    }
}

struct StatusIndicator: View {
    let isConnected: Bool
    var body: some View {
        HStack {
            Circle().fill(isConnected ? Color.green : Color.red).frame(width: 10, height: 10)
            Text(isConnected ? "Online" : "Offline").font(.caption)
        }
    }
}
