import SwiftUI
import Network
import AVKit
import Combine

class RobotDogController: ObservableObject {
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var currentKey: String = ""
    @Published var batteryLevel: Int = 0 // 0-100
    @Published var wifiStrength: Int = 0 // 0-3
    
    init(initialBattery: Int = 0) {
        self.batteryLevel = initialBattery
    }
    
    private var connection: NWConnection?
    private let ctrlIP = "192.168.2.1"
    private let ctrlPort: UInt16 = 43893
    private let localPort: UInt16 = 20001
    
    func connect() {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ctrlIP), port: NWEndpoint.Port(integerLiteral: ctrlPort))
        let parameters = NWParameters.udp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.any), port: NWEndpoint.Port(integerLiteral: localPort))
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.wifiStrength = 3 // 连接成功时立即显示强信号
                    self?.startHeartbeat()
                case .failed(let error):
                    self?.isConnected = false
                    self?.connectionError = "连接失败: \(error.localizedDescription)"
                case .waiting(let error):
                    self?.connectionError = "等待连接: \(error.localizedDescription)"
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: .main)
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        // 保留真实的电量数据，不重置为0
        wifiStrength = 0
    }
    
    private func startHeartbeat() {
        sendCommand(code: 0x21040001)
        startStatusUpdates()
    }
    
    private func startStatusUpdates() {
        // 定期更新状态信息
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateRobotStatus()
        }
    }
    
    func updateRobotStatus() {
        // 在实际应用中，这里应该发送状态查询命令并解析返回的数据
        // 现在使用JSON中的真实电量数据，只在连接时进行微调
        
        if isConnected {
            // WiFi信号保持强信号状态（绿色）
            wifiStrength = 3 // 始终显示最强信号
        }
    }
    
    func sendCommand(code: UInt32, param1: Int32 = 0, param2: Int32 = 0) {
        guard isConnected else { return }
        
        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: code.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: param1.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: param2.littleEndian) { Array($0) })
        
        connection?.send(content: payload, completion: .contentProcessed { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.connectionError = "发送命令失败: \(error.localizedDescription)"
                }
            }
        })
    }
    
    func handleKeyPress(_ key: String) {
        currentKey = key.uppercased()
        
        switch key.lowercased() {
        case "w": sendCommand(code: 0x21010130, param1: 32767)  // 前进
        case "s": sendCommand(code: 0x21010130, param1: -32767) // 后退
        case "a": sendCommand(code: 0x21010131, param1: -32767) // 左平移
        case "d": sendCommand(code: 0x21010131, param1: 32767)  // 右平移
        case "q": sendCommand(code: 0x21010135, param1: -32767) // 左转
        case "e": sendCommand(code: 0x21010135, param1: 32767)  // 右转
        case "z": sendCommand(code: 0x21010202)                 // 起立/趴下
        case "x": sendCommand(code: 0x21010C05)                 // 回零
        case "c": sendCommand(code: 0x21010D06)                 // 移动模式
        case "r": sendCommand(code: 0x21010307)                 // 中速
        case "t": sendCommand(code: 0x21010303)                 // 高速
        case "y": sendCommand(code: 0x21010406)                 // 正常/匍匐
        case "u": sendCommand(code: 0x21010402)                 // 抓地
        case "i": sendCommand(code: 0x21010401)                 // 越障
        case "v": sendCommand(code: 0x21010407)                 // 高踏步
        case "b": sendCommand(code: 0x21010C02)                 // 手动模式
        case "n": sendCommand(code: 0x21010C03)                 // 导航模式
        case "p": sendCommand(code: 0x21010C0E)                 // 软急停
        default: break
        }
    }
    
    func handleKeyRelease(_ key: String) {
        switch key.lowercased() {
        case "w", "s": sendCommand(code: 0x21010130, param1: 0)  // 停止前进/后退
        case "a", "d": sendCommand(code: 0x21010131, param1: 0)  // 停止平移
        case "q", "e": sendCommand(code: 0x21010135, param1: 0)  // 停止转向
        default: break
        }
    }
}

// 机器狗实时控制界面
struct DogBotControlView: View {
    let botName: String
    let initialBattery: Int // 从JSON获取的初始电量
    @Environment(\.dismiss) private var dismiss
    @StateObject private var robotController: RobotDogController
    
    init(botName: String, initialBattery: Int) {
        self.botName = botName
        self.initialBattery = initialBattery
        self._robotController = StateObject(wrappedValue: RobotDogController(initialBattery: initialBattery))
    }
    @State private var selectedCamera: CameraMode = .dogCamera
    @State private var selectedPosture: PostureMode = .standUp
    @State private var selectedTerrain: TerrainMode = .flatLand
    @State private var showLoading = true
    
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
            // 视频背景 - 填充整个屏幕，根据摄像头模式切换
            Image(selectedCamera == .dogCamera ? "机器狗摄像头" : "机械臂摄像头")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(.all) // 恢复全屏显示
                .animation(.easeInOut(duration: 0.3), value: selectedCamera) // 添加切换动画
            
            // 顶部原生分段控制器（摄像头切换）
            GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    Picker("摄像头", selection: $selectedCamera) {
                        Text("机器狗摄像头画面").tag(CameraMode.dogCamera)
                        Text("机械臂摄像头画面").tag(CameraMode.armCamera)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                }
                    .padding(.horizontal, geometry.size.width * 0.02) // 使用相对定位
                    .padding(.top, geometry.size.height * 0.015) // 使用相对定位
                    
                    Spacer()
                }
            }
                
            // 右侧控制按钮（纵向居中）
            GeometryReader { geometry in
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
                        .padding(.trailing, geometry.size.width * 0.03) // 使用相对定位
                }
                
                Spacer()
                }
            }
            
            // 右上角紧急停止按钮
            GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                            robotController.handleKeyPress("p") // 软急停
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
                        .padding(.trailing, geometry.size.width * 0.015) // 使用相对定位
                        .padding(.top, geometry.size.height * 0.02) // 使用相对定位
                    }
                    Spacer()
                }
            }
            
            // 底部控制区域 - 根据摄像头模式显示不同内容
            if selectedCamera == .dogCamera {
                // 机器狗摄像头画面 - 方向控制盘（右下角）
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 20) {
                                // 左转右转控制条
                                HStack(spacing: 46) {
                                    // 左转按钮
                                    Button(action: {}) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 55, height: 40)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in robotController.handleKeyPress("q") }
                                            .onEnded { _ in robotController.handleKeyRelease("q") }
                                    )
                                    // 右转按钮
                                    Button(action: {}) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 55, height: 40)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in robotController.handleKeyPress("e") }
                                            .onEnded { _ in robotController.handleKeyRelease("e") }
                                    )
                                }
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(40)
                                // 原有的方向控制盘
                                DirectionControlPad(
                                    onForward: { robotController.handleKeyPress("w") },
                                    onBackward: { robotController.handleKeyPress("s") },
                                    onLeft: { robotController.handleKeyPress("a") },
                                    onRight: { robotController.handleKeyPress("d") },
                                    onStopForwardBackward: { robotController.handleKeyRelease("w") },
                                    onStopLeftRight: { robotController.handleKeyRelease("a") }
                                )
                            }
                            .padding(.trailing, geometry.size.width * 0.02)
                            .padding(.bottom, geometry.size.height * 0.01)
                        }
                    }
                }
            }
            if selectedCamera == .armCamera {
                // 机械臂摄像头画面 - 底部控制区域
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            // 左下角 - 摄像头缩放控制区域
                            VStack(spacing: 14) {
                                // 上方缩放按钮组
                                HStack(spacing: 20) {
                                    // 拉近按钮
                                    Button(action: {}) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color("accentPurple"))
                                            Text("拉近")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in /* 拉近功能 */ }
                                            .onEnded { _ in /* 停止拉近 */ }
                                    )
                                    // 远离按钮
                                    Button(action: {}) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.right.and.arrow.up.left.square")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color("accentPurple"))
                                            Text("远离")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in /* 远离功能 */ }
                                            .onEnded { _ in /* 停止远离 */ }
                                    )
                                }
                                // 摄像头控制盘
                                CameraZoomControlPad()
                            }
                            .padding(.leading, geometry.size.width * 0.02)
                            .padding(.bottom, geometry.size.height * 0.01)
                            Spacer()
                            // 右下角 - 机械臂控制区域
                            VStack(spacing: 14) {
                                // 上方机械臂按钮组
                                HStack(spacing: 30) {
                                    // 夹/松按钮
                                    Button(action: {}) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "scissors")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color("accentPurple"))
                                            Text("夹/松")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in /* 夹/松功能 */ }
                                            .onEnded { _ in /* 停止 */ }
                                    )
                                    // 放入按钮
                                    Button(action: {}) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "shippingbox")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color("accentPurple"))
                                            Text("放入")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in /* 放入功能 */ }
                                            .onEnded { _ in /* 停止 */ }
                                    )
                                }
                                // 机械臂控制盘
                                RobotArmControlPad()
                            }
                            .padding(.trailing, geometry.size.width * 0.02)
                            .padding(.bottom, geometry.size.height * 0.01)
                        }
                    }
                }
            }
            
            // 底部分段控制器（姿态和地形控制）- 仅在机器狗摄像头画面显示
            if selectedCamera == .dogCamera {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // 姿态控制
                            Picker("姿态", selection: $selectedPosture) {
                                Text("起立").tag(PostureMode.standUp)
                                Text("趴下").tag(PostureMode.lieDown)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .onChange(of: selectedPosture) {
                                robotController.handleKeyPress("z") // 起立/趴下切换
                            }
                            
                            // 地形控制
                            Picker("地形", selection: $selectedTerrain) {
                                Text("平地").tag(TerrainMode.flatLand)
                                Text("越障").tag(TerrainMode.obstacle)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .onChange(of: selectedTerrain) {
                                switch selectedTerrain {
                                case .flatLand:
                                    robotController.handleKeyPress("u") // 抓地模式，适合平地
                                case .obstacle:
                                    robotController.handleKeyPress("i") // 越障模式
                                }
                            }
                            
                            Spacer() // 推到左侧
                        }
                        .padding(.leading, geometry.size.width * 0.03) // 使用相对定位
                        .padding(.bottom, geometry.size.height * 0.01) // 减少底部空白
                    }
                }
            }
            if showLoading {
                DogBotLoadingOverlay()
                    .zIndex(1000)
            }
        }
        .navigationTitle("控制面板")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .onAppear {
            // 自动连接机器狗
            if !robotController.isConnected {
                robotController.connect()
            }
            if showLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 17) {
                    showLoading = false
                }
            }
        }
        .toolbar {
            // 左侧返回按钮
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
 //                       Text("返回")
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
                        Text("\(robotController.batteryLevel)%")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(batteryColor)
                }
                
                // 刷新按钮
                Button(action: {
                    robotController.updateRobotStatus() // 手动刷新状态
                }) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
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
        switch robotController.wifiStrength {
        case 0: return "wifi.slash"
        case 1: return "wifi"
        case 2: return "wifi"
        case 3: return "wifi"
        default: return "wifi"
        }
    }
    
    // WiFi信号颜色
    private var wifiColor: Color {
        switch robotController.wifiStrength {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return Color("primaryGreen")
        default: return .gray
        }
    }
    
    // 电量图标
    private var batteryIcon: String {
        switch robotController.batteryLevel {
        case 0...20: return "battery.25"
        case 21...50: return "battery.50"
        case 51...80: return "battery.75"
        default: return "battery.100" // 81%+
        }
    }
    
    // 电量颜色 (与控制面板保持一致)
    private var batteryColor: Color {
        switch robotController.batteryLevel {
        case 81...: return Color("dogGreen")        // 81%+ 深绿色
        case 61...80: return Color("dogGreen")      // 61-80% 深绿色
        case 51...60: return Color("dogOrange")     // 51-60% 橙色
        case 21...50: return Color("dogRed")        // 21-50% 红色
        default: return Color("dogRed")             // ≤20% 红色
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
    let onForward: () -> Void
    let onBackward: () -> Void
    let onLeft: () -> Void
    let onRight: () -> Void
    let onStopForwardBackward: () -> Void
    let onStopLeftRight: () -> Void
    
    var body: some View {
        ZStack {
            // 半透明圆形背景
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 180, height: 180)
            
            // 上方向按钮
            VStack {
                DirectionButton(icon: "chevron.up", 
                    onPress: onForward,
                    onRelease: onStopForwardBackward
                )
                
                Spacer()
                
                DirectionButton(icon: "chevron.down",
                    onPress: onBackward,
                    onRelease: onStopForwardBackward
                )
            }
            .frame(height: 180)
            
            // 左右方向按钮
            HStack {
                DirectionButton(icon: "chevron.left",
                    onPress: onLeft,
                    onRelease: onStopLeftRight
                )
                
                Spacer()
                
                DirectionButton(icon: "chevron.right",
                    onPress: onRight,
                    onRelease: onStopLeftRight
                )
            }
            .frame(width: 180)
        }
    }
}

// 方向按钮
struct DirectionButton: View {
    let icon: String
    let onPress: () -> Void
    let onRelease: () -> Void
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPress()
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

// 摄像头指示盘（机械臂摄像头画面 - 左下角）
struct CameraZoomControlPad: View {
    var body: some View {
        ZStack {
            // 半透明圆形背景
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 180, height: 180)
            
            // 四个方向箭头
            VStack {
                CameraDirectionButton(icon: "chevron.up")
                Spacer()
                CameraDirectionButton(icon: "chevron.down")
            }
            .frame(height: 180)
            
            HStack {
                CameraDirectionButton(icon: "chevron.left")
                Spacer()
                CameraDirectionButton(icon: "chevron.right")
            }
            .frame(width: 180)
            
            // 中心绿色摄像头图标
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(Color("primaryGreen"))
        }
    }
}

// 摄像头方向按钮
struct CameraDirectionButton: View {
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // TODO: 摄像头方向控制功能
                }
                .onEnded { _ in
                    // TODO: 停止摄像头方向控制
                }
        )
    }
}

// 机械臂控制盘（机械臂摄像头画面 - 右下角）  
struct RobotArmControlPad: View {
    var body: some View {
        ZStack {
            // 半透明圆形背景
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 180, height: 180)
            
            // 上下方向按钮
            VStack {
                ArmRotationButton(icon: "chevron.up")
                Spacer()
                ArmRotationButton(icon: "chevron.down")
            }
            .frame(height: 180)
            
            // 左右方向按钮
            HStack {
                ArmRotationButton(icon: "arrow.counterclockwise")
                Spacer()
                ArmRotationButton(icon: "arrow.clockwise")
            }
            .frame(width: 180)
            
            // 中心手控图标
            Image(systemName: "tuningfork")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("primaryGreen"))
                .scaleEffect(x: -1, y: 1) // 左右镜像
        }
    }
}

// 机械臂旋转按钮
struct ArmRotationButton: View {
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // 旋转功能
                }
                .onEnded { _ in
                    // 停止旋转
                }
        )
    }
}

#Preview("Full Screen Control", traits: .landscapeLeft, body: {
    DogBotControlView(botName: "绝影lite3-A1", initialBattery: 78)

})
 
 
