import Foundation
import UIKit

struct MessageBubble: Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let image: UIImage?
    let thinkingTime: Int?

    init(content: String, isUser: Bool, image: UIImage? = nil, thinkingTime: Int? = nil) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.image = image
        self.thinkingTime = thinkingTime
    }

    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp, imageData, thinkingTime
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(thinkingTime, forKey: .thinkingTime)
        if let image = image, let data = image.jpegData(compressionQuality: 0.6) {
            try container.encode(data, forKey: .imageData)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        thinkingTime = try container.decodeIfPresent(Int.self, forKey: .thinkingTime)
        if let data = try container.decodeIfPresent(Data.self, forKey: .imageData) {
            image = UIImage(data: data)
        } else {
            image = nil
        }
    }
}
