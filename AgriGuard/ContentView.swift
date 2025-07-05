//
//  ContentView.swift
//  AgriGuard
//
//  Created by mart S on 2025/6/29.
//

import SwiftUI
import MapKit
import Foundation

enum Menu: String, CaseIterable, Identifiable {
    case dashboard = "田野看板"
    case info = "信息面板"
    case control = "控制面板"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .info: return "map"
        case .control: return "dog"
        }
    }
    var selectedIcon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .info: return "map.fill"
        case .control: return "dog.fill"
        }
    }
}

// 单个菜单项
struct SidebarMenuRow: View {
    let menu: Menu
    let selected: Bool
    let mainColor: Color
    let selectedBg: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(selectedBg)
                        .frame(height: 44)
                        .padding(.horizontal, 4)
                }
                HStack(spacing: 12) {
                    Image(systemName: selected ? menu.selectedIcon : menu.icon)
                        .foregroundColor(selected ? mainColor : .primary)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, alignment: .center) // 固定图标宽度确保对齐
                    Text(menu.rawValue)
                        .font(.headline)
                        .foregroundColor(selected ? mainColor : .primary)
                    Spacer() // 确保内容左对齐
                }
                .padding(.horizontal, 22)
                .frame(height: 44, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 确保整个区域都可以点击
        }
        .buttonStyle(.plain) // 移除默认按钮样式
    }
}

struct InspectionTaskModal: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    @Binding var selectedFields: [String]
    @Binding var selectedRobot: String
    @Binding var selectedMode: String
    let allFields: [String]
    let allRobots: [String]
    let allModes: [String]
    
    var body: some View {
        VStack(spacing: 0) {
            // 只保留弹窗主体，无BubblePointer
            VStack(spacing: 0) {
                Text("新的巡检任务")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                Divider()
                VStack(spacing: 0) {
                    ModalRow(label: "时间", content: {
                        HStack(spacing: 8) {
                            Text(dateString)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 可弹出日期选择器
                        }
                    })
                    Divider()
                    ModalRow(label: "巡检范围", content: {
                        HStack(spacing: 8) {
                            Text(selectedFields.joined(separator: "、"))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 可弹出多选菜单
                        }
                    })
                    Divider()
                    ModalRow(label: "机器人", content: {
                        HStack(spacing: 8) {
                            Text(selectedRobot)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 可弹出单选菜单
                        }
                    })
                    Divider()
                    ModalRow(label: "巡逻模式", content: {
                        HStack(spacing: 8) {
                            Text(selectedMode)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 可弹出单选菜单
                        }
                    })
                }
                Divider()
                Button(action: {
                    // 创建巡检任务逻辑
                    isPresented = false
                }) {
                    Text("创建巡检任务")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color("primaryGreen"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .frame(width: 360)
        }
    }
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: selectedDate)
    }
}

struct ModalRow<Content: View>: View {
    let label: String
    let content: () -> Content
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 72, alignment: .leading)
            content()
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
    }
}

struct BubblePointer: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width, h = geo.size.height
                path.move(to: CGPoint(x: w * 0.2, y: 0))
                path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w * 0.35, y: h * 0.7))
                path.addQuadCurve(to: CGPoint(x: w * 0.8, y: 0), control: CGPoint(x: w * 0.65, y: h * 0.7))
                path.closeSubpath()
            }
            .fill(Color.white)
            .shadow(radius: 2, y: 1)
        }
    }
}

struct ContentView: View {
    @State private var selectedRecord: PestDiseaseRecord? = nil
    @State private var selectedSidebar: Menu = .dashboard
    @State private var showWeatherPopup = false
    @StateObject private var weatherService = WeatherConfig.createWeatherService()
    let mainColor = Color("primaryGreen")
    let selectedBg = Color("selectedGreen")
    @State private var showInspectionModal = false
    
    // 当前选择的区域
    @State private var currentRegion = "区域A"
    @State private var currentCoordinate = CLLocationCoordinate2D(latitude: 30.30661441116419, longitude: 120.0803089141845)
    // 巡检任务参数
    @State private var selectedDate = Date()
    @State private var selectedFields: [String] = ["小麦A", "小麦B", "小麦C"]
    @State private var selectedRobot = "绝影lite3-A1"
    @State private var selectedMode = "仅一次"
    let allFields = ["小麦A", "小麦B", "小麦C", "小麦D"]
    let allRobots = ["绝影lite3-A1", "绝影lite3-A2"]
    let allModes = ["仅一次", "定时循环"]

    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 0) {
                    // 侧边栏标题
                    List {
                        ForEach(Menu.allCases) { menu in
                            SidebarMenuRow(menu: menu,
                                           selected: selectedSidebar == menu,
                                           mainColor: mainColor,
                                           selectedBg: selectedBg) {
                                selectedSidebar = menu
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollDisabled(true)
                    // 自动填充空间的Spacer
                    Spacer()
                    // 底部按钮区域
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 16)
                        Button(action: {
                            showInspectionModal = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("开始巡检")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Capsule()
                                    .fill(mainColor)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .navigationTitle("AgriGuard")
            } detail: {
                switch selectedSidebar {
                case .dashboard:
                    FieldDashboardView()
                        .navigationTitle("田野看板")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup, regionName: currentRegion)
                            }
                        }
                case .info:
                    InfoPanelView(selectedRecord: $selectedRecord)
                        .navigationTitle("信息面板")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup, regionName: currentRegion)
                            }
                        }
                case .control:
                    ControlPanelView()
                        .navigationTitle("控制面板")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup, regionName: currentRegion)
                            }
                        }
                }
            }
            // 弹窗全局 overlay，浮在主内容区左下角
            .overlay(alignment: .bottomLeading) {
                if showInspectionModal {
                    ZStack(alignment: .bottomLeading) {
                        Color.black.opacity(0.01)
                            .ignoresSafeArea()
                            .onTapGesture { showInspectionModal = false }
                        InspectionTaskModal(
                            isPresented: $showInspectionModal,
                            selectedDate: $selectedDate,
                            selectedFields: $selectedFields,
                            selectedRobot: $selectedRobot,
                            selectedMode: $selectedMode,
                            allFields: allFields,
                            allRobots: allRobots,
                            allModes: allModes
                        )
                        .padding(.leading, 32)
                        .padding(.bottom, 85) // 下移弹窗
                        .zIndex(101)
                    }
                }
            }
            // 全局弹窗遮罩
            if let record = selectedRecord {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { selectedRecord = nil }
                TreatmentLogModal(
                    record: record,
                    isPresented: Binding(
                        get: { selectedRecord != nil },
                        set: { newValue in if !newValue { selectedRecord = nil } }
                    )
                )
                .frame(maxWidth: 420)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(radius: 24)
                .transition(.scale)
            }
        }
        .navigationTitle("AgriGuard")
        .overlay {
            // 天气弹窗叠加层
            if showWeatherPopup {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showWeatherPopup = false
                    }
                    .overlay(alignment: .topTrailing) {
                        WeatherPopupView(weatherService: weatherService, isPresented: $showWeatherPopup, regionName: currentRegion, coordinate: currentCoordinate)
                            .padding(.top, 65)
                            .padding(.trailing, 30)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showWeatherPopup)
                            .onTapGesture {
                                // 防止点击弹窗内容时关闭
                            }
                    }
                    .zIndex(1000)
            }
        }
        .onAppear {
            weatherService.fetchWeatherForCoordinate(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SwitchToControlPanelTab"), object: nil, queue: .main) { _ in
                selectedSidebar = .control
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RegionChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let regionName = userInfo["regionName"] as? String,
               let coordinate = userInfo["coordinate"] as? CLLocationCoordinate2D {
                currentRegion = regionName
                currentCoordinate = coordinate
                weatherService.fetchWeatherForCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
    }
}

// 假设InfoPanelView是主内容区的一部分
struct MainContentView: View {
    @Binding var selectedRecord: PestDiseaseRecord?
    var body: some View {
        InfoPanelView(selectedRecord: $selectedRecord)
        // 其他主内容...
    }
}

#Preview(traits:.landscapeRight) {
    ContentView()
}
