import SwiftUI
import MapKit
import Combine
import Foundation

// JSON对应的田块数据结构
struct FieldData: Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

// JSON对应的区域数据结构
struct RegionData: Codable {
    let id: String
    let name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let fields: [FieldData]
}

// 田块数据结构
struct Field: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    
    init(from fieldData: FieldData) {
        self.id = fieldData.id
        self.name = fieldData.name
        self.coordinate = CLLocationCoordinate2D(
            latitude: fieldData.latitude,
            longitude: fieldData.longitude
        )
    }
    
    static func == (lhs: Field, rhs: Field) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// 区域数据结构
struct Region: Identifiable, Equatable {
    let id: String
    let name: String
    let center: CLLocationCoordinate2D
    let fields: [Field]
    
    init(from regionData: RegionData) {
        self.id = regionData.id
        self.name = regionData.name
        self.center = CLLocationCoordinate2D(
            latitude: regionData.centerLatitude,
            longitude: regionData.centerLongitude
        )
        self.fields = regionData.fields.map { Field(from: $0) }
    }
    
    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.fields == rhs.fields
    }
}

// 区域选择弹窗按钮
struct RegionSelectorButton: View {
    let selectedRegion: Region
    let regions: [Region]
    let onRegionSelected: (Region) -> Void
    @State private var showingMenu = false
    
    var body: some View {
        Button(action: {
            showingMenu = true
        }) {
            HStack(spacing: 6) {
                Text(selectedRegion.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("选择区域", isPresented: $showingMenu, titleVisibility: .visible) {
            ForEach(regions, id: \.id) { region in
                Button(region.name) {
                    onRegionSelected(region)
                    // 发送区域变化通知
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RegionChanged"),
                        object: nil,
                        userInfo: [
                            "regionName": region.name,
                            "coordinate": region.center
                        ]
                    )
                }
            }
            Button("取消", role: .cancel) { }
        }
    }
}

// 田块多边形数据结构
struct FieldPolygon: Identifiable, Codable {
    let id: String
    let name: String
    let coordinates: [Coordinate]
    struct Coordinate: Codable {
        let longitude: Double
        let latitude: Double
    }
}

// 田块多边形加载器
class FieldPolygonLoader: ObservableObject {
    @Published var polygons: [FieldPolygon] = []
    init() { load() }
    func load() {
        if let url = Bundle.main.url(forResource: "field_polygons", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let polygons = try? JSONDecoder().decode([FieldPolygon].self, from: data) {
            self.polygons = polygons
        }
    }
}

// 标记点数据结构
struct FieldAlert: Identifiable, Codable, Equatable {
    var type: String
    var longitude: Double
    var latitude: Double
    var id: String { "\(type)-\(longitude)-\(latitude)" }
}

class FieldAlertLoader: ObservableObject {
    @Published var alerts: [FieldAlert] = []
    init() { load() }
    func load() {
        if let url = Bundle.main.url(forResource: "field_alerts", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let alerts = try? JSONDecoder().decode([FieldAlert].self, from: data) {
            self.alerts = alerts
        }
    }
}

// 警告气泡视图
struct AlertBubble: View {
    let type: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type == "发现虫害" ? "ladybug.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))
            Text(type)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(type == "发现虫害" ? Color.orange : Color(red: 1, green: 0.29, blue: 0.29))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

// 气泡+圆点视图
struct AlertBubbleWithDot: View {
    let type: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AlertBubble(type: type)
            Circle()
                .fill(type == "发现虫害" ? Color.orange : Color(red: 1, green: 0.29, blue: 0.29))
                .frame(width: 8, height: 8)
                .offset(x: 0, y: 12) // 与气泡有一定距离
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
    }
}

// 标准水滴形状
struct WaterDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let center = CGPoint(x: width / 2, y: width / 2)
        let radius = width / 2
        // 上半部分为圆
        path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(540), clockwise: false)
        // 下半部分为尖
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: 0, y: height * 0.85)
        )
        path.addQuadCurve(
            to: CGPoint(x: width, y: width / 2),
            control: CGPoint(x: width, y: height * 0.85)
        )
        path.closeSubpath()
        return path
    }
}

// 电量颜色规则
func dogColor(for battery: Int) -> Color {
    switch battery {
    case 81...: return Color("dogGreen")
    case 61...80: return Color("dogGreen")
    case 51...60: return Color("dogOrange")
    case 21...50: return Color("dogRed")
    default: return Color("dogRed")
    }
}

// 新增dogAccentColor和dogIconColor函数
func dogAccentColor(for battery: Int) -> Color {
    switch battery {
    case 81...: return Color("dogAccentGreen")
    case 61...80: return Color("dogAccentGreen")
    case 51...60: return Color("dogAccentOrange")
    case 21...50: return Color("dogAccentRed")
    default: return Color("dogAccentRed")
    }
}
func dogIconColor(for battery: Int) -> Color {
    switch battery {
    case 81...: return Color("dogGreen")
    case 61...80: return Color("dogGreen")
    case 51...60: return Color("dogOrange")
    case 21...50: return Color("dogRed")
    default: return Color("dogRed")
    }
}

// 狗定位气泡标记
struct DogBotMarker: View {
    let name: String
    let battery: Int
    var body: some View {
        VStack(spacing: 0) {
            // 顶部编号气泡
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(dogIconColor(for: battery))
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                .padding(.bottom, 2)
            // 大圆+狗icon
            ZStack {
                Circle()
                    .fill(dogAccentColor(for: battery))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                Image(systemName: "dog.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(dogIconColor(for: battery))
            }
            // 间距
            Spacer().frame(height: 6)
            // 小圆点
            Circle()
                .fill(dogAccentColor(for: battery))
                .frame(width: 10, height: 10)
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
    }
}

// 田块地图视图
struct FieldMapView: View {
    let selectedRegion: Region
    let regions: [Region]
    let onRegionSelected: (Region) -> Void
    let showAlerts: Bool
    let onAlertTap: (FieldAlert) -> Void
    let selectedTab: FieldDashboardView.DashboardTab
    let onFieldPolygonTap: (FieldPolygon) -> Void
    @State private var position: MapCameraPosition
    @StateObject private var polygonLoader = FieldPolygonLoader()
    @StateObject private var alertLoader = FieldAlertLoader()
    @StateObject private var botLoader = DogBotStatusLoader()
    @StateObject private var pestHistoryLoader = PestHistoryCircleLoader()
    @State private var selectedAlert: FieldAlert? = nil
    @State private var selectedFieldPolygon: FieldPolygon? = nil

    init(selectedRegion: Region, regions: [Region], onRegionSelected: @escaping (Region) -> Void, showAlerts: Bool, onAlertTap: @escaping (FieldAlert) -> Void, selectedTab: FieldDashboardView.DashboardTab, onFieldPolygonTap: @escaping (FieldPolygon) -> Void) {
        self.selectedRegion = selectedRegion
        self.regions = regions
        self.onRegionSelected = onRegionSelected
        self.showAlerts = showAlerts
        self.onAlertTap = onAlertTap
        self.selectedTab = selectedTab
        self.onFieldPolygonTap = onFieldPolygonTap
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: selectedRegion.center,
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        )))
    }

    func fieldColors(for name: String) -> (fill: Color, stroke: Color) {
        if name.contains("小麦") {
            return (Color("wheatFill"), Color("wheatStroke"))
        } else if name.contains("玉米") {
            return (Color("cornFill"), Color("cornStroke"))
        }
        return (.gray, .black)
    }

    func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coords.isEmpty else { return nil }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                // 绘制所有田块多边形和名称
                ForEach(polygonLoader.polygons) { polygon in
                    let coords = polygon.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    let colors = fieldColors(for: polygon.name)
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(colors.fill)
                        .stroke(colors.stroke, lineWidth: 2)
                    if let center = centroid(of: coords) {
                        Annotation("", coordinate: center) {
                            Button(action: {
                                print("点击了田块", polygon.name)
                                if polygon.name == "小麦A" {
                                    onFieldPolygonTap(polygon)
                                }
                            }) {
                                Text(polygon.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(colors.stroke)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // 原有田块 Marker
                ForEach(selectedRegion.fields) { field in
                    Marker(field.name, coordinate: field.coordinate)
                        .tint(.green)
                }
                // 警告标记点
                if showAlerts {
                    ForEach(alertLoader.alerts) { alert in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)) {
                            Button(action: {
                                onAlertTap(alert)
                            }) {
                                AlertBubbleWithDot(type: alert.type)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // 狗定位标记
                    ForEach(botLoader.bots) { bot in
                        Annotation(bot.name, coordinate: CLLocationCoordinate2D(latitude: bot.latitude, longitude: bot.longitude)) {
                            DogBotMarker(
                                name: bot.name.replacingOccurrences(of: "绝影lite3-", with: ""),
                                battery: bot.battery
                            )
                        }
                    }
                }
                // 病虫害历史圆
                if selectedTab == .history {
                    ForEach(pestHistoryLoader.circles) { circle in
                        MapCircle(center: CLLocationCoordinate2D(latitude: circle.latitude, longitude: circle.longitude), radius: circle.radius) // 半径单位可根据地图缩放调整
                            .foregroundStyle(circle.type == "虫害" ? Color.yellow.opacity(0.5) : Color.red.opacity(0.5))
                            .stroke(circle.type == "虫害" ? Color.yellow : Color.red, lineWidth: 2)
                    }
                }
            }
            .onChange(of: selectedRegion.id) { 
                // 当区域改变时，移动地图中心
                withAnimation(.easeInOut(duration: 0.5)) {
                    position = .region(MKCoordinateRegion(
                        center: selectedRegion.center,
                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
                    ))
                }
            }
            // 区域选择按钮 - 位于地图上方中间
            RegionSelectorButton(
                selectedRegion: selectedRegion, 
                regions: regions,
                onRegionSelected: onRegionSelected
            )
            .padding(.top, 16)
        }
    }
}

// 只对底部和左右加圆角的扩展
struct BottomRoundedRectangle: Shape {
    var radius: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// 机器狗数据结构
struct DogBot: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let icon: String // systemName
}

// 机器狗列表视图
struct DogBotListView: View {
    let bots: [DogBot]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(bots) { bot in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(bot.color.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "dog.fill")
                            .foregroundColor(bot.color)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(bot.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#4B5563"))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // "添加机器狗"按钮
            HStack(spacing: 8) {
                ZStack {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .font(.system(size: 20, weight: .bold))
                }
                Text("添加机器狗")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#4B5563"))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 32)
        .padding(.top, 32)
        .padding(.bottom, 32)
    }
}

// 机器狗状态结构体
struct DogBotStatus: Identifiable, Codable {
    let id: String
    let name: String
    let battery: Int
    let latitude: Double
    let longitude: Double
    let lastUpdate: String
}

// 机器狗状态加载器
class DogBotStatusLoader: ObservableObject {
    @Published var bots: [DogBotStatus] = []
    init() {
        load()
    }
    func load() {
        if let url = Bundle.main.url(forResource: "dogbots", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            if let bots = try? JSONDecoder().decode([DogBotStatus].self, from: data) {
                self.bots = bots
            }
        }
    }
}

// 区域数据加载器
class RegionLoader: ObservableObject {
    @Published var regions: [Region] = []
    
    init() {
        loadRegions()
    }
    
    func loadRegions() {
        guard let url = Bundle.main.url(forResource: "regions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let regionDataArray = try? JSONDecoder().decode([RegionData].self, from: data) else {
            print("❌ 无法加载区域数据")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.regions = regionDataArray.map { Region(from: $0) }
        }
    }
}

// 新增植物/设置禁区按钮
struct EditMapButton: View {
    let icon: String
    let iconColor: Color
    let borderStyle: StrokeStyle?
    let text: String
    let action: () -> Void
    var isActive: Bool = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    if let borderStyle = borderStyle {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(iconColor, style: borderStyle)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(iconColor)
                    }
                }
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#4B5563"))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(isActive ? Color("selectedGreen") : Color.white.opacity(0.95))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// 发现虫害弹窗卡片
struct PestAlertCard: View {
    var onClose: () -> Void
    var onCreateTask: () -> Void
    var onIgnore: () -> Void
    var image: Image
    var region: String
    var timeAgo: String
    var pestTitle: String = "发现虫害"
    var pestDesc: String = "发现虫虫害的早期迹象。"
    var suggestions: [String] = [
        "及时拍照被害严重的叶片，保持田间清洁，及时清理、带离受害残体。",
        "用低毒高效的药剂进行药剂防治。",
        "合理密植，避免过度施肥，增强植株抗性。"
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题栏
            HStack(alignment: .center) {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.orange)
                    .clipShape(Circle())
                Text(pestTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#FF9900"))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            // 图片区域
            ZStack(alignment: .bottomTrailing) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                Text("拍摄于\(timeAgo)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)
                    .padding(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            // 拍摄区域
            Text("拍摄区域：\(region)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            // AI分析
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "#FF9900"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发现虫害")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#FF9900"))
                        Text(pestDesc)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }
                // 治理建议
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(hex: "#FF9900"))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("治理建议")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        ForEach(suggestions, id: \.self) { s in
                            Text("• \(s)")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "#FFF7E6"))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            // 按钮区
            HStack(spacing: 16) {
                Button(action: onCreateTask) {
                    Text("创建机器狗任务")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("primaryGreen"))
                        .cornerRadius(10)
                }
                Button(action: onIgnore) {
                    Text("忽略")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("dogRed"))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 4)
        .frame(width: 340)
    }
}

// 新增田块拍摄记录弹窗
struct FieldPhotoCard: View {
    var onClose: () -> Void
    var images: [Image]
    var fieldName: String
    var time: String
    var statusTitle: String = "生长状况"
    var statusDesc: String = "植物生长状况良好。"
    var onCreateTask: (() -> Void)? = nil
    @State private var selectedIndex: Int = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部栏
            HStack(alignment: .center) {
                Text(fieldName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            // 图片区域（可滑动，比例与发现虫害一致）
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \ .offset) { idx, img in
                    ZStack(alignment: .bottomTrailing) {
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                        HStack {
                            Spacer()
                            Text(time)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                        }
                        .padding(8)
                    }
                    .tag(idx)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .frame(height: 220)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            // 状态卡片
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Color("primaryGreen"))
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(statusDesc)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
      //      .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            // 创建任务按钮
            if let onCreateTask = onCreateTask {
                Button(action: onCreateTask) {
                    Text("创建机器狗任务")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("primaryGreen"))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 4)
        .frame(width: 340)
    }
}

// 田野看板主视图
struct FieldDashboardView: View {
    @StateObject private var regionLoader = RegionLoader()
    @State private var selectedRegion: Region?
    @State private var selectedFieldPolygon: FieldPolygon? = nil
    @State private var showLoading = false
    @State private var navigateToControlPanel = false
    @State private var selectedBot: DogBotStatus? = nil

    enum DashboardTab: String, CaseIterable, Identifiable {
        case current = "当前情况"
        case photo = "拍摄记录"
        case history = "病虫害历史"
        case edit = "编辑地图"
        var id: String { rawValue }
    }
    @State private var selectedTab: DashboardTab = .current
    @StateObject private var botLoader = DogBotStatusLoader()
    @State private var drawingStart: CGPoint? = nil
    @State private var drawingEnd: CGPoint? = nil
    @State private var drawingRotation: Angle = .zero
    @State private var isDrawing = false
    @State private var selectedAlert: FieldAlert? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 16)
            .padding(.horizontal, 16)
            Spacer(minLength: 16)
            ZStack(alignment: .leading) {
                if selectedTab == .edit {
                    ZStack {
                        if let selectedRegion = selectedRegion {
                            FieldMapView(
                                selectedRegion: selectedRegion, 
                                regions: regionLoader.regions,
                                    onRegionSelected: { newRegion in self.selectedRegion = newRegion },
                                    showAlerts: false,
                                    onAlertTap: { _ in },
                                    selectedTab: selectedTab,
                                    onFieldPolygonTap: { polygon in selectedFieldPolygon = polygon }
                            )
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                        GeometryReader { geo in
                            ZStack {
                                if let start = drawingStart, let end = drawingEnd {
                                    Rectangle()
                                        .strokeBorder(Color("primaryGreen"), lineWidth: 2)
                                        .background(Color("primaryGreen").opacity(0.2))
                                        .frame(
                                            width: abs(end.x - start.x),
                                            height: abs(end.y - start.y)
                                        )
                                        .position(
                                            x: (start.x + end.x) / 2,
                                            y: (start.y + end.y) / 2
                                        )
                                        .rotationEffect(drawingRotation)
                                        .gesture(
                                            RotationGesture()
                                                .onChanged { angle in
                                                    drawingRotation = angle
                                                }
                                        )
                                }
                                VStack(alignment: .leading, spacing: 12) {
                                    EditMapButton(
                                        icon: "viewfinder",
                                        iconColor: Color("primaryGreen"),
                                        borderStyle: nil,
                                        text: "新增植物",
                                        action: {
                                            if isDrawing {
                                                isDrawing = false
                                                drawingStart = nil
                                                drawingEnd = nil
                                                drawingRotation = .zero
                                            } else {
                                                isDrawing = true
                                                drawingStart = nil
                                                drawingEnd = nil
                                                drawingRotation = .zero
                                            }
                                        },
                                        isActive: isDrawing
                                    )
                                    EditMapButton(
                                        icon: "nosign",
                                        iconColor: .red,
                                        borderStyle: nil,
                                        text: "设置禁区"
                                    ) {
                                        // TODO: 禁区功能
                                    }
                                }
                                .padding(.leading, 36)
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                isDrawing ?
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if drawingStart == nil {
                                            drawingStart = value.startLocation
                                            drawingEnd = value.location
                                        } else {
                                            drawingEnd = value.location
                                        }
                                    }
                                    .onEnded { value in
                                        drawingEnd = value.location
                                        // 保持isDrawing为true，直到用户再次点击按钮退出
                                    }
                                : nil
                            )
                        }
                    }
                } else {
                    if let selectedRegion = selectedRegion {
                            ZStack {
                        FieldMapView(
                            selectedRegion: selectedRegion, 
                            regions: regionLoader.regions,
                                    onRegionSelected: { newRegion in self.selectedRegion = newRegion },
                                    showAlerts: selectedTab == .current || selectedTab == .photo,
                                    onAlertTap: { alert in selectedAlert = alert },
                                    selectedTab: selectedTab,
                                    onFieldPolygonTap: { polygon in
                                        print("onFieldPolygonTap回调", polygon.name)
                                        selectedFieldPolygon = polygon
                            }
                        )
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                                // 弹窗和遮罩只覆盖地图区域
                                if let alert = selectedAlert {
                                    ZStack {
                                        Color.black.opacity(0.18)
                                            .cornerRadius(16)
                                            .onTapGesture { selectedAlert = nil }
                                        PestAlertCard(
                                            onClose: { selectedAlert = nil },
                                            onCreateTask: {
                                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToControlPanelTab"), object: nil)
                                            },
                                            onIgnore: { selectedAlert = nil },
                                            image: Image("发现虫害"),
                                            region: "玉米A",
                                            timeAgo: "2小时前"
                                        )
                                        .frame(maxWidth: 340)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 32)
                                        .transition(.scale)
                                        .zIndex(1)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    .zIndex(100)
                                }
                            }
                    }
                }
                if selectedTab == .current || selectedTab == .photo {
                    DogBotListView(bots: botLoader.bots.map { bot in
                        DogBot(name: bot.name, color: {
                            switch bot.battery {
                            case 81...: return Color("dogGreen")        // 81%+ 深绿色
                            case 61...80: return Color("dogGreen")      // 61-80% 深绿色
                            case 51...60: return Color("dogOrange")     // 51-60% 橙色
                            case 21...50: return Color("dogRed")        // 21-50% 红色
                            default: return Color("dogRed")             // ≤20% 红色
                            }
                        }(), icon: "dog.fill")
                    })
                    .frame(width: 220)
                    .padding(.top, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if selectedTab == .photo, let polygon = selectedFieldPolygon, polygon.name == "小麦A" {
                ZStack {
                    Color.black.opacity(0.18)
                        .cornerRadius(16)
                        .onTapGesture { selectedFieldPolygon = nil }
                    FieldPhotoCard(
                        onClose: { selectedFieldPolygon = nil },
                        images: [Image("小麦A")],
                        fieldName: polygon.name,
                        time: "5月18日 12:58",
                        statusTitle: "生长状况",
                        statusDesc: "植物生长状况良好。",
                        onCreateTask: {
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToControlPanelTab"), object: nil)
                        }
                    )
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .transition(.scale)
                    .zIndex(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .zIndex(100)
            }
            if showLoading {
                DogBotLoadingOverlay()
                    .zIndex(200)
            }
            if navigateToControlPanel, let bot = selectedBot {
                DogBotControlView(botName: bot.name, initialBattery: bot.battery)
                    .zIndex(300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            regionLoader.loadRegions()
        }
        .onChange(of: regionLoader.regions) {
            // 当区域数据加载完成后，选择第一个区域
            if selectedRegion == nil && !regionLoader.regions.isEmpty {
                selectedRegion = regionLoader.regions[0]
            }
            }
        }
    }
}

struct PestHistoryCircle: Identifiable, Codable {
    let id = UUID()
    let longitude: Double
    let latitude: Double
    let radius: Double
    let type: String // "虫害" or "病害"
}

class PestHistoryCircleLoader: ObservableObject {
    @Published var circles: [PestHistoryCircle] = []
    init() { load() }
    func load() {
        if let url = Bundle.main.url(forResource: "pest_history_circles", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let circles = try? JSONDecoder().decode([PestHistoryCircle].self, from: data) {
            self.circles = circles
        }
    }
}

#Preview(traits:.landscapeRight) {
    FieldDashboardView()
} 
