//
//  Model.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 09/02/26.
//


import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let senderID: String
    let senderName: String
    let content: String
    let roomID: String
    let timestamp: Date
}
