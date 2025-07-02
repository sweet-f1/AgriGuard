import SwiftUI

// 机器狗实时控制界面
struct DogBotControlView: View {
    let botName: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCamera: CameraMode = .dogCamera
    @State private var selectedPosture: PostureMode = .standUp
    @State private var selectedTerrain: TerrainMode = .flatLand
    @State private var wifiStrength: Int = 3 // 0-3
    @State private var batteryLevel: Int = 78 // 0-100
    
    enum CameraMode: String, CaseIterable {
        case dogCamera = "机器狗摄像头画面"
        case armCamera = "机械臂摄像头画面"
    }
    
    enum PostureMode: String, CaseIterable {
        case standUp = "起立"
        case lieDown = "趴下"
    }
    
    enum TerrainMode: String, CaseIterable {
        case flatLand = "平地"
        case obstacle = "越障"
    }
    
    var body: some View {
        ZStack {
            // 视频背景 - 填充整个屏幕
            Image("机器狗摄像头")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea(.all)
            
            // 顶部分段控制器
            VStack {
                HStack {
                    Spacer()
                    Picker("摄像头", selection: $selectedCamera) {
                        ForEach(CameraMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 380)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 80) // 为导航栏留出空间，但不紧贴
                
                Spacer()
            }
            
            // 底部分段控制器
            VStack {
                Spacer()
                
                HStack(spacing: 24) {
                    // 姿态控制
                    Picker("姿态", selection: $selectedPosture) {
                        ForEach(PostureMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 142)
                    
                    // 地形控制
                    Picker("地形", selection: $selectedTerrain) {
                        ForEach(TerrainMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 142)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60) // 在视频区域内，不贴底部
            }
                
            // 右侧控制按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 框选按钮
                        ControlButton(
                            icon: "viewfinder",
                            title: "框选",
                            backgroundColor: Color("primaryGreen"),
                            foregroundColor: .white
                        ) {
                            // 框选功能
                        }
                        
                        // 拍摄按钮
                        ControlButton(
                            icon: "camera.fill",
                            title: "拍摄",
                            backgroundColor: Color("primaryGreen"),
                            foregroundColor: .white
                        ) {
                            // 拍摄功能
                        }
                    }
                    .padding(.trailing, 20)
                }
                Spacer()
                    .frame(height: 200) // 为底部控制器和方向盘留更多空间
            }
            
            // 右上角紧急停止按钮
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // 紧急停止
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                            Text("紧急停止")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60) // 为导航栏留空间
                }
                Spacer()
            }
            
            // 方向控制盘（右下角）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DirectionControlPad()
                        .padding(.trailing, 40)
                        .padding(.bottom, 140) // 为底部控制器留空间
                }
            }
        }
        .navigationTitle("控制面板")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // 左侧返回按钮
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                        Text("返回")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(Color("primaryGreen"))
                }
            }
            
            // 右侧控制按钮组
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // WiFi信号强度
                Button(action: {
                    // WiFi设置
                }) {
                    Image(systemName: wifiSignalIcon)
                        .font(.system(size: 17))
                        .foregroundColor(wifiColor)
                }
                
                // 电量显示
                Button(action: {
                    // 电量详情
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 17))
                        Text("\(batteryLevel)%")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(batteryColor)
                }
                
                // 刷新按钮
                Button(action: {
                    // 刷新连接
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                        .foregroundColor(Color("primaryGreen"))
                }
                
                // 设置按钮
                Button(action: {
                    // 设置
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 17))
                        .foregroundColor(Color("primaryGreen"))
                }
            }
        }
    }
    
    // WiFi信号图标
    private var wifiSignalIcon: String {
        switch wifiStrength {
        case 0: return "wifi.slash"
        case 1: return "wifi"
        case 2: return "wifi"
        case 3: return "wifi"
        default: return "wifi"
        }
    }
    
    // WiFi信号颜色
    private var wifiColor: Color {
        switch wifiStrength {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return Color("primaryGreen")
        default: return .gray
        }
    }
    
    // 电量图标
    private var batteryIcon: String {
        switch batteryLevel {
        case 0...20: return "battery.25"
        case 21...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    // 电量颜色
    private var batteryColor: Color {
        switch batteryLevel {
        case 0...20: return .red
        case 21...50: return .orange
        default: return Color("primaryGreen")
        }
    }
}

// 控制按钮组件
struct ControlButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(8)
        }
    }
}

// 方向控制盘
struct DirectionControlPad: View {
    var body: some View {
        ZStack {
            // 半透明圆形背景
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 160, height: 160)
            
            // 上方向按钮
            VStack {
                DirectionButton(icon: "chevron.up") {
                    // 前进
                }
                .offset(y: -55)
                
                Spacer()
                
                DirectionButton(icon: "chevron.down") {
                    // 后退
                }
                .offset(y: 55)
            }
            .frame(height: 160)
            
            // 左右方向按钮
            HStack {
                DirectionButton(icon: "chevron.left") {
                    // 左转
                }
                .offset(x: -55)
                
                Spacer()
                
                DirectionButton(icon: "chevron.right") {
                    // 右转
                }
                .offset(x: 55)
            }
            .frame(width: 160)
        }
    }
}

// 方向按钮
struct DirectionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color("primaryGreen"))
                .clipShape(Circle())
        }
    }
}

#Preview("Full Screen Control", traits: .landscapeLeft, body: {
    // 模拟全屏控制界面
    NavigationView {
        DogBotControlView(botName: "绝影lite3-A1")
    }
    .navigationViewStyle(.stack) // 强制stack模式，避免split view
}) 
