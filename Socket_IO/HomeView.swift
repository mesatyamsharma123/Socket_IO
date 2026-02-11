//
//  HomeView.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import Foundation
import SwiftUI

struct HomeView: View {
    // Shared state yahan declare hogi
    @StateObject private var socketManager = SocketManagerClient()
    @State private var roomId: String = ""

    var body: some View {
        TabView {
            NavigationStack {
                // 'roomID' ka name exact wahi hona chahiye jo ContentView mein hai
                ContentView(socketManager: socketManager, roomID: $roomId)
            }
            .tabItem { Label("Chats", systemImage: "message.fill") }

            NavigationStack {
                // AudioChatView ka init humne upar define kiya tha
                AudioChatView(roomId: $roomId, socketManager: socketManager)
            }
            .tabItem { Label("Audio", systemImage: "phone.fill") }
            
            NavigationStack {
                VideoChatView()
            }
            .tabItem { Label("Video", systemImage: "video.fill") }
        }
    }
}
