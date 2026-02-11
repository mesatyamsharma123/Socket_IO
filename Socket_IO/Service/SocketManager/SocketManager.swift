import Foundation
import SocketIO
import Combine

class SocketManagerClient: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var chat: [ChatMessage] = []
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    
    // UserID ko static rakhein taaki UI alignment na bigde
    let currentUserID: String = UUID().uuidString
    let currentUserName: String = "Satyam \(Int.random(in: 1000...9999))"

    override init() {
        super.init()
        setupConnection()
    }

    func setupConnection() {
        let url = URL(string: "https://e28c-106-51-65-110.ngrok-free.app")!
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
        encoder.dateEncodingStrategy = .iso8601
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
            decoder.dateDecodingStrategy = .iso8601

            do {
                let incomingMsg = try decoder.decode(ChatMessage.self, from: jsonData)
                DispatchQueue.main.async {
               
                    self.chat.append(incomingMsg)
                }
            } catch {
                print("Decoding Error: \(error)")
            }
        }
    }
}
