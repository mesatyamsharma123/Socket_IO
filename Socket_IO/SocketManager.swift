import Foundation
import SocketIO
import Combine
// Industry Standard Message Model

class SocketManagerClient: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var chat: [ChatMessage] = []
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    
    
    let currentUserID = UUID().uuidString
    let currentUserName = "User \(Int.random(in: 1...1000))"

    override init() {
        super.init()
        setupConnection()
    }

    func setupConnection() {
        let url = URL(string: "https://cb9b-106-51-65-110.ngrok-free.app")!
        manager = SocketManager(socketURL: url, config: [.log(false), .compress])
        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { _, _ in
            DispatchQueue.main.async { self.isConnected = true }
        }

        socket.on(clientEvent: .disconnect) { _, _ in
            DispatchQueue.main.async { self.isConnected = false }
        }

        addListenEvent()
    }

    func connect() { socket.connect() }
    func disconnect() { socket.disconnect() }

    func joinRoom(id: String) {
        socket.emit("join_room", id)
    }

    func send(message: String, roomId: String) {
        let newMessage = ChatMessage(
            id: UUID(),
            senderID: currentUserID,
            senderName: currentUserName,
            content: message,
            roomID: roomId,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.chat.append(newMessage)
        }

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(newMessage),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            socket.emit("send_message", json)
        }
    }

    func addListenEvent() {
        socket.on("new_message") { [weak self] (data, _) in
            guard let self = self,
                  let json = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: json) else { return }

            let decoder = JSONDecoder()
          
            
            do {
                let incomingMsg = try decoder.decode(ChatMessage.self, from: jsonData)
                
                DispatchQueue.main.async {
  
                    if incomingMsg.senderID != self.currentUserID {
                        if !self.chat.contains(where: { $0.id == incomingMsg.id }) {
                            self.chat.append(incomingMsg)
                        }
                    }
                }
            } catch {
                print("❌ Still failing: \(error)")
            }
        }
    
    }
}
