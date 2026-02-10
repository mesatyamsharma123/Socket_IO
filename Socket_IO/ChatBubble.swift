//
//  ChatBubble.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import Foundation
import SwiftUI

struct ChatBubble : View {
    
    let message: ChatMessage
    let isMe: Bool
    var body: some View {
       
        HStack{
            if isMe {Spacer()}
            VStack(alignment: isMe ? .trailing : .leading){
                if !isMe {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Text(message.content)
                    .padding(10)
                    .background(isMe ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isMe ? .white : .primary)
                    .cornerRadius(12)
                
            }
            if !isMe {Spacer()}
        }
        .padding(.horizontal, 10)
    }
}
