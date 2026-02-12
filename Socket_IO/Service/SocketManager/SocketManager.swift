import Foundation
import SocketIO
import Combine


protocol SocketManagerClientProtocol: AnyObject {
    func SocketManagerClientProtocol(_ client: SocketManagerClient,didReceiveRemoteOffer: String,username: String,roomId: String)
    func SocketManagerClientProtocol(_ client: SocketManagerClient,didReceiveRemoteAnswer: String,username: String,roomId: String)
    func SocketManagerClientProtocol(_ client: SocketManagerClient,didReceiveRemoteICECandidate candidate: [String:Any],roomId: String)
    
}


class SocketManagerClient: NSObject, ObservableObject {
    weak var delegate: SocketManagerClientProtocol?
    
    static let shared = SocketManagerClient()
    @Published var isConnected: Bool = false
    @Published var chat: [ChatMessage] = []
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    
  
    let currentUserID: String = UUID().uuidString
    let currentUserName: String = "Satyam \(Int.random(in: 1000...9999))"

    override init() {
        super.init()
        setupConnection()
        afterConnect()
    }

    func setupConnection() {
        let url = URL(string: "https://3bc0-106-51-65-110.ngrok-free.app")!
        manager = SocketManager(socketURL: url, config: [.log(false), .compress,.forceWebsockets(true),.reconnects(true)])
        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { _, _ in
            DispatchQueue.main.async { self.isConnected = true }
        }

        socket.on(clientEvent: .disconnect) { _, _ in
            DispatchQueue.main.async { self.isConnected = false }
        }

        addListenEvent()
        listenOffer()
        listenAnswer()
        listenCandidate()
        self.listenForEndCall { [weak self] in
                // Ye handle karega jab doosra user call kaate
                print("📱 End call received in SocketManager")
            }
    }

    func connect() {
        socket.connect()
        
        print("Connected to server")
    }
    
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
            print("this is josn data",json)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let incomingMsg = try decoder.decode(ChatMessage.self, from: jsonData)
                DispatchQueue.main.async {
               
                    self.chat.append(incomingMsg)
                    print("this is incoing message ",incomingMsg)
                }
            } catch {
                print("Decoding Error: \(error)")
            }
        }
    }
    
    func sendOffer(sdp: String, usename: String, roomId: String) {
     
        let message: [String: Any] = [
            "username": usename,
            "sdp": sdp,
            "roomId": roomId
        ]
        socket.emit("audio_offer", message)
        print("Offer emitted for room: \(roomId)")
    }
    func sendAnswer(sdp: String, usename: String,roomId:String) {
        print(roomId)
        
        let message:[String: Any] = [ "username": usename,"sdp": sdp,"roomId":roomId]
        socket.emit("audio_answer", message)
    }
    func sendCandidate(candidate: [String: Any]) {
        // ViewModel ne jo dictionary bheji hai (candidateDict),
        // usme pehle se 'roomId' maujood hai.
        // Isliye humein usey extract karke top-level par bhejna chahiye
        // agar aapka server aisa expect kar raha hai.
        
        let roomId = candidate["roomId"] as? String ?? ""
        
        let message: [String: Any] = [
            "candidate": candidate, // Pura candidate object (sdpMid, sdpMLineIndex, etc.)
            "roomId": roomId        // Server isse identify karega ki kaha bhejna hai
        ]
        
        socket.emit("audio_candidate", message)
        print("❄️ Candidate emitted to room: \(roomId)")
    }
    
    func listenOffer() {
        socket.on("audio_offer") { [weak self] (data, _) in
            guard let self = self else { return }
            guard let dict = data.first as? [String: Any] else { return }
            if let username = dict["username"] as? String, let sdp = dict["sdp"] as? String ,let roomId = dict["roomId"] as? String {
                print("Received offer from: \(username), sdp: \(sdp),id: \(roomId)")
                delegate?.SocketManagerClientProtocol(self, didReceiveRemoteOffer:  sdp, username: username,roomId:roomId)
                
               
            } else {
                print("audio_offer payload missing expected keys: \(dict)")
            }
        }
    }

    func listenAnswer() {
        socket.on("audio_answer") { [weak self] (data, _) in
            guard let self = self else { return }
            guard let dict = data.first as? [String: Any] else { return }
            if let username = dict["username"] as? String, let sdp = dict["sdp"] as? String, let rooomId = dict["roomId"] as? String {
                print("Received answer from: \(username), sdp: \(sdp)")
                delegate?.SocketManagerClientProtocol(self, didReceiveRemoteAnswer:  sdp, username: username,roomId: rooomId)
               
            } else {
                print("audio_answer payload missing expected keys: \(dict)")
            }
        }
    }

    func listenCandidate() {
        socket.on("audio_candidate") { [weak self] (data, _) in
            guard let self = self else { return }
            guard let dict = data.first as? [String: Any] else { return }
            if let candidate = dict["candidate"] as? [String: Any],let roomId = dict["roomId"] as? String  {
                print("Received ICE candidate: \(candidate)")
                delegate?.SocketManagerClientProtocol(self, didReceiveRemoteICECandidate: candidate,roomId: roomId)
               
            } else {
                print("audio_candidate payload missing candidate key: \(dict)")
            }
        }
    }
    
    func afterConnect(){
        
        socket.on(clientEvent: .connect) { _,_ in
               print("connect with server")
               
           }
    }
    func endCall(roomId: String) {
        let message: [String: Any] = ["roomId": roomId, "username": currentUserName]
        socket.emit("end_call", message)
    }

    // listenEndCall function ko setupConnection() mein add karein
    func listenForEndCall(completion: @escaping () -> Void) {
        socket.on("end_call") { data, _ in
            print("📞 Received end_call from server")
            completion()
        }
    }
}
