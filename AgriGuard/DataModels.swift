import Foundation

// 机器狗状态数据结构
struct DogBotInfo: Identifiable, Codable {
    let id: String
    let name: String
    let battery: Int
    let status: String
    let records: Int
    let latitude: Double
    let longitude: Double
    let lastUpdate: String
} 