//
//  ContentView.swift
//  AgriGuard
//
//  Created by mart S on 2025/6/29.
//

import SwiftUI
import MapKit
import Foundation

// hex 颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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

struct ContentView: View {
    @State private var selection: Menu? = .dashboard
    @State private var showWeatherPopup = false
    @StateObject private var weatherService = WeatherConfig.createWeatherService()
    let mainColor = Color("primaryGreen")
    let selectedBg = Color("selectedGreen")
    
    // 当前选择的区域
    @State private var currentRegion = "区域A"
    @State private var currentCoordinate = CLLocationCoordinate2D(latitude: 30.30661441116419, longitude: 120.0803089141845)

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // 菜单列表区域
                List {
                    ForEach(Menu.allCases) { menu in
                        SidebarMenuRow(menu: menu,
                                       selected: selection == menu,
                                       mainColor: mainColor,
                                       selectedBg: selectedBg) {
                            selection = menu
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.sidebar)
                .scrollDisabled(true) // 禁用滚动，因为菜单项不多
                
                // 自动填充空间的Spacer
                Spacer()
                
                // 底部按钮区域
                VStack(spacing: 0) {
                    // 分隔线
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // 开始巡检按钮
                    Button(action: {
                        // 巡检逻辑
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
            switch selection {
            case .dashboard:
                VStack(alignment: .leading, spacing: 0) {
                    FieldDashboardView()
                }
                .navigationTitle("田野看板")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup, regionName: currentRegion)
                    }
                }
            case .info:
                InfoPanelView()
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
            default:
                Text("请选择功能")
            }
        }
        .overlay {
            // 天气弹窗叠加层
            if showWeatherPopup {
                // 透明背景，点击关闭弹窗
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showWeatherPopup = false
                    }
                    .overlay(alignment: .topTrailing) {
                        WeatherPopupView(weatherService: weatherService, isPresented: $showWeatherPopup, regionName: currentRegion, coordinate: currentCoordinate)
                            .padding(.top, 65) // 调整距顶部距离，确保在导航栏下方
                            .padding(.trailing, 30) // 调整距右侧距离
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showWeatherPopup)
                            .onTapGesture {
                                // 防止点击弹窗内容时关闭
                            }
                    }
                    .zIndex(1000) // 确保在最顶层
            }
        }
        .onAppear {
            // 应用启动时获取地图位置的天气数据
            weatherService.fetchWeatherForCoordinate(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RegionChanged"))) { notification in
            // 监听区域变化通知
            if let userInfo = notification.userInfo,
               let regionName = userInfo["regionName"] as? String,
               let coordinate = userInfo["coordinate"] as? CLLocationCoordinate2D {
                currentRegion = regionName
                currentCoordinate = coordinate
                // 获取新区域的天气数据
                weatherService.fetchWeatherForCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
    }
}



#Preview(traits:.landscapeRight) {
    ContentView()
}
