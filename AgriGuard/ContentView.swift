//
//  ContentView.swift
//  AgriGuard
//
//  Created by mart S on 2025/6/29.
//

import SwiftUI

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

    var body: some View {
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
                Text(menu.rawValue)
                    .font(.headline)
                    .foregroundColor(selected ? mainColor : .primary)
            }
            .padding(.horizontal, 22)
            .frame(height: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentView: View {
    @State private var selection: Menu? = .dashboard
    @State private var showWeatherPopup = false
    @StateObject private var weatherService = WeatherConfig.createWeatherService()
    let mainColor = Color("primaryGreen")
    let selectedBg = Color("selectedGreen")

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // 只留导航栏标题，无 logo，无顶部 Section
                ForEach(Menu.allCases) { menu in
                    SidebarMenuRow(menu: menu,
                                   selected: selection == menu,
                                   mainColor: mainColor,
                                   selectedBg: selectedBg)
                        .tag(menu)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // Spacer 占位让按钮吸底（利用 Section，适配大屏幕）
                Section {
                    Spacer()
                        .frame(height: 650) // 可根据你实际 sidebar 高度微调
                }

                // 底部按钮
                Section {
                    HStack {
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
                        .padding(.horizontal, 4)
                    }
                }
            }
            .listStyle(.sidebar)
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
                        WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup)
                    }
                }
            case .info:
                Text("信息面板内容")
                    .font(.largeTitle)
                    .navigationTitle("信息面板")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup)
                        }
                    }
            case .control:
                Text("控制面板内容")
                    .font(.largeTitle)
                    .navigationTitle("控制面板")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            WeatherAvatarView(weatherService: weatherService, showWeatherPopup: $showWeatherPopup)
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
                        WeatherPopupView(weatherService: weatherService, isPresented: $showWeatherPopup)
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
            // 应用启动时获取天气数据
            weatherService.fetchCurrentWeather()
        }
    }
}











#Preview(traits:.landscapeLeft) {
    ContentView()
}
