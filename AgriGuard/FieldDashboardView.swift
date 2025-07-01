import SwiftUI
import MapKit
import Combine

// 田块数据结构
struct Field: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// 田块地图视图
struct FieldMapView: View {
    let fields: [Field]
    @State private var position: MapCameraPosition

    init(fields: [Field], center: CLLocationCoordinate2D) {
        self.fields = fields
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        )))
    }

    var body: some View {
        Map(position: $position) {
            ForEach(fields) { field in
                Marker(field.name, coordinate: field.coordinate)
                    .tint(.green)
            }
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

// 田野看板主视图
struct FieldDashboardView: View {
    // mock 田块数据
    let fields = [
        Field(name: "地块A", coordinate: CLLocationCoordinate2D(latitude: 30.30661441116419, longitude: 120.0803089141845))
    ]
    let center = CLLocationCoordinate2D(latitude: 30.30661441116419, longitude: 120.0803089141845)

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

    var body: some View {
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
                        FieldMapView(fields: fields, center: center)
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
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
                                        icon: "",
                                        iconColor: Color("primaryGreen"),
                                        borderStyle: StrokeStyle(lineWidth: 2, dash: [6,3]),
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
                    FieldMapView(fields: fields, center: center)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                if selectedTab == .current || selectedTab == .photo {
                    DogBotListView(bots: botLoader.bots.map { bot in
                        DogBot(name: bot.name, color: {
                            switch bot.battery {
                            case 61...: return Color("dogGreen")
                            case 21...60: return Color("dogOrange")
                            default: return Color("dogRed")
                            }
                        }(), icon: "dog.fill")
                    })
                    .frame(width: 220)
                    .padding(.top, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview(traits:.landscapeLeft) {
    FieldDashboardView()
} 
