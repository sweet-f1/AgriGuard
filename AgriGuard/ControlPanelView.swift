import SwiftUI
import Foundation
import Combine

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

// 机器狗数据加载器
class DogBotDataLoader: ObservableObject {
    @Published var bots: [DogBotInfo] = []
    
    init() {
        loadBots()
    }
    
    func loadBots() {
        guard let url = Bundle.main.url(forResource: "dogbots", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decodedBots = try? JSONDecoder().decode([DogBotInfo].self, from: data) else {
            print("❌ 无法加载机器狗数据")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.bots = decodedBots
        }
    }
}

// 机器狗卡片视图
struct DogBotCard: View {
    let bot: DogBotInfo
    let onTap: () -> Void
    
    // 根据电量确定背景色
    private var batteryColor: Color {
        switch bot.battery {
        case 81...: return Color("dogAccentGreen")      // 89% A4 - 浅绿色
        case 61...80: return Color("dogAccentGreen")    // 78% A1 - 浅绿色
        case 51...60: return Color("dogAccentOrange")   // 56% A3 - 浅橙色/黄色
        case 21...50: return Color("dogAccentRed")      // 
        default: return Color("dogAccentRed")           // 20% A2 - 浅红色
        }
    }
    
    // 根据电量确定图标颜色
    private var iconColor: Color {
        switch bot.battery {
        case 81...: return Color("dogGreen")      // 89% A4 - 深绿色
        case 61...80: return Color("dogGreen")    // 78% A1 - 深绿色  
        case 51...60: return Color("dogOrange")   // 56% A3 - 橙色
        case 21...50: return Color("dogRed")      // 
        default: return Color("dogRed")           // 20% A2 - 红色
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    // 机器狗图标
                    ZStack {
                        Circle()
                            .fill(batteryColor)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "dog.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(iconColor)
                    }
                    
                    VStack(spacing: 10) {
                        // 名称和定位图标
                        HStack {
                            Text(bot.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "#1F2937"))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))
                        }
                        
                        // 状态标签
                        HStack(spacing: 8) {
                            // 电量标签
                            Text("电量\(bot.battery)%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#4B5563"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(batteryColor)
                                .cornerRadius(14)
                            
                            // 状态标签
                            Text(bot.status)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#4B5563"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#F3F4F6"))
                                .cornerRadius(14)
                            
                            // 记录数标签
                            Text("\(bot.records)条记录")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#4B5563"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#F3F4F6"))
                                .cornerRadius(14)
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// 添加机器狗长条按钮
struct AddDogBotCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#4B5563"))
                
                Text("添加机器狗")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#4B5563"))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(height: 72) // 长条按钮高度
            .frame(maxWidth: .infinity) // 占据全宽
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// 控制面板主视图
struct ControlPanelView: View {
    @StateObject private var dogBotLoader = DogBotDataLoader()
    @State private var showWiFiAlert = false
    @State private var selectedBot: DogBotInfo?
    @State private var navigateToControl = false
    
    // 卡片网格布局
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 机器狗卡片网格
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(dogBotLoader.bots) { bot in
                        DogBotCard(bot: bot) {
                            selectedBot = bot
                            showWiFiAlert = true
                        }
                    }
                }
                
                // 添加机器狗长条按钮
                AddDogBotCard {
                    // TODO: 添加机器狗逻辑
                    print("添加机器狗")
                }
            }
            .padding(16)
        }
        .background(Color(hex: "#F9FAFB"))
        .onAppear {
            dogBotLoader.loadBots()
        }
        .alert("WiFi 连接提示", isPresented: $showWiFiAlert) {
            Button("确认") {
                showWiFiAlert = false
                navigateToControl = true
            }
        } message: {
            Text("请确保已连接\(selectedBot?.name ?? "机器狗")的WiFi以保证它的可用性。")
        }
        .tint(Color("primaryGreen"))
        .fullScreenCover(isPresented: $navigateToControl) {
            NavigationView {
                if let bot = selectedBot {
                    DogBotControlView(botName: bot.name, initialBattery: bot.battery)
                }
            }
        }
    }
}

#Preview(traits:.landscapeRight) {
    ControlPanelView()
} 
 
