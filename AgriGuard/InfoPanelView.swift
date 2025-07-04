//
//  InfoPanelView.swift
//  AgriGuard
//
//  Created by mart S on 2025/6/29.
//

import SwiftUI
import Foundation
import Combine

// hex 颜色扩展
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

// MARK: - 数据模型
struct PestDiseaseRecord: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let cropName: String
    let timestamp: String
    let dateDisplay: String
    let riskLevel: String
    let riskLevelText: String
    let description: String
    let imageName: String
    let treatmentSuggestion: String
    let tags: [Tag]
    
    // 虫害特有字段
    let pestForm: String?
    let damageArea: String?
    
    // 病害特有字段
    let pathogenType: String?
    let transmission: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, description, tags
        case cropName = "crop_name"
        case dateDisplay = "date_display"
        case riskLevel = "risk_level"
        case riskLevelText = "risk_level_text"
        case imageName = "image_name"
        case treatmentSuggestion = "treatment_suggestion"
        case pestForm = "pest_form"
        case damageArea = "damage_area"
        case pathogenType = "pathogen_type"
        case transmission
    }
}

struct Tag: Codable, Sendable {
    let label: String
    let type: String
}

struct PestDiseaseData: Codable, Sendable {
    let pestRecords: [PestDiseaseRecord]
    let diseaseRecords: [PestDiseaseRecord]
    let summary: Summary
    
    enum CodingKeys: String, CodingKey {
        case pestRecords = "pest_records"
        case diseaseRecords = "disease_records"
        case summary
    }
}

struct Summary: Codable, Sendable {
    let pestCount: Int
    let diseaseCount: Int
    let totalCount: Int
    let lastUpdate: String
    
    enum CodingKeys: String, CodingKey {
        case pestCount = "pest_count"
        case diseaseCount = "disease_count"
        case totalCount = "total_count"
        case lastUpdate = "last_update"
    }
}

struct TrendMetric: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let currentValue: Int
    let unit: String
    let weeklyChange: Int
    let weeklyChangeText: String
    let trend: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, unit, trend
        case currentValue = "current_value"
        case weeklyChange = "weekly_change"
        case weeklyChangeText = "weekly_change_text"
    }
}

struct TrendAnalysisData: Codable, Sendable {
    let title: String
    let lastUpdate: String
    let metrics: [TrendMetric]
    
    enum CodingKeys: String, CodingKey {
        case title, metrics
        case lastUpdate = "last_update"
    }
}

struct WorkLog: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let title: String
    let time: String
    let robotId: String
    let taskType: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, time, description
        case robotId = "robot_id"
        case taskType = "task_type"
    }
}

struct WorkLogData: Codable, Sendable {
    let title: String
    let filter: FilterData
    let logs: [WorkLog]
    
    struct FilterData: Codable, Sendable {
        let selected: String
        let options: [String]
    }
}

// MARK: - 数据管理器
class InfoPanelDataManager: ObservableObject {
    @Published var pestDiseaseData: PestDiseaseData?
    @Published var trendData: TrendAnalysisData?
    @Published var workLogData: WorkLogData?
    @Published var selectedCropFilter = "全部作物"
    @Published var selectedRobotFilter = "全部机器狗"
    @Published var isLoading = false
    
    init() {
        loadData()
    }
    
    func loadData() {
        isLoading = true
        
        // 使用简单的Task.detached来避免并发问题
        Task.detached {
            // 加载病虫害数据
            let pestDiseaseData = await Self.loadPestDiseaseData()
            
            // 加载趋势分析数据
            let trendData = await Self.loadTrendAnalysisData()
            
            // 加载工作日志数据
            let workLogData = await Self.loadWorkLogData()
            
            // 在主线程更新UI
            await MainActor.run {
                self.pestDiseaseData = pestDiseaseData
                self.trendData = trendData
                self.workLogData = workLogData
                if let workLog = workLogData {
                    self.selectedRobotFilter = workLog.filter.selected
                }
                self.isLoading = false
            }
        }
    }
    
    // 静态方法来加载数据，避免并发问题
    private static func loadPestDiseaseData() async -> PestDiseaseData? {
        guard let url = Bundle.main.url(forResource: "pest_disease_info", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(PestDiseaseData.self, from: data)
    }
    
    private static func loadTrendAnalysisData() async -> TrendAnalysisData? {
        guard let url = Bundle.main.url(forResource: "trend_analysis", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(TrendAnalysisData.self, from: data)
    }
    
    private static func loadWorkLogData() async -> WorkLogData? {
        guard let url = Bundle.main.url(forResource: "work_logs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(WorkLogData.self, from: data)
    }
    
    var filteredPestRecords: [PestDiseaseRecord] {
        guard let data = pestDiseaseData else { return [] }
        if selectedCropFilter == "全部作物" {
            return data.pestRecords
        }
        return data.pestRecords.filter { $0.cropName.contains(selectedCropFilter) }
    }
    
    var filteredDiseaseRecords: [PestDiseaseRecord] {
        guard let data = pestDiseaseData else { return [] }
        if selectedCropFilter == "全部作物" {
            return data.diseaseRecords
        }
        return data.diseaseRecords.filter { $0.cropName.contains(selectedCropFilter) }
    }
    
    var filteredWorkLogs: [WorkLog] {
        guard let data = workLogData else { return [] }
        if selectedRobotFilter == "全部机器狗" {
            return data.logs
        }
        return data.logs.filter { $0.robotId == selectedRobotFilter }
    }
}

// MARK: - 主要视图
struct InfoPanelView: View {
    @StateObject private var dataManager = InfoPanelDataManager()
    
    var body: some View {
        if dataManager.isLoading {
            ProgressView("加载中...")
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        // 左侧：作物信息 (固定合理宽度)
                        CropInfoSection(dataManager: dataManager)
                            .frame(width: min(geometry.size.width * 0.6, 550))
                        
                        // 右侧：趋势分析和工作日志 (占用所有剩余空间)
                        VStack(spacing: 16) {
                            TrendAnalysisSection(dataManager: dataManager)
                            WorkLogSection(dataManager: dataManager)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }
            }
            .background(Color(hex: "#F9FAFB"))
        }
    }
}

// MARK: - 作物信息区域
struct CropInfoSection: View {
    @ObservedObject var dataManager: InfoPanelDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            // 标题和筛选器
            HStack {
                Text("作物信息")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 作物筛选器
                    SwiftUI.Menu(content: {
                        Button("全部作物") { dataManager.selectedCropFilter = "全部作物" }
                        Button("玉米") { dataManager.selectedCropFilter = "玉米" }
                        Button("小麦") { dataManager.selectedCropFilter = "小麦" }
                    }, label: {
                        HStack(spacing: 3) {
                            Text(dataManager.selectedCropFilter)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("primaryGreen"))
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(Color("primaryGreen"))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(6)
                    })
                    
                    // 日期显示
                    HStack(spacing: 5) {
                        Text("2025年")
                            .fontWeight(.semibold)
                            .foregroundColor(Color("primaryGreen"))
                        Text("5月19日")
                            .fontWeight(.semibold)
                            .foregroundColor(Color("primaryGreen"))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }
            }
            
            // 虫害信息区域
            PestInfoSection(dataManager: dataManager)
                .padding(.horizontal, 8)
            
            // 病害信息区域
            DiseaseInfoSection(dataManager: dataManager)
                .padding(.horizontal, 8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 虫害信息区域
struct PestInfoSection: View {
    @ObservedObject var dataManager: InfoPanelDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack {
                HStack(spacing: 12) {
                    // 虫害图标
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "ladybug")
                            .font(.title2)
                            .foregroundColor(Color("primaryGreen"))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("虫害信息")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("2小时前更新")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 记录数量
                Text("\(dataManager.filteredPestRecords.count)条记录")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color("primaryGreen"))
                    .cornerRadius(99)
            }
            
            // 虫害卡片列表
            if dataManager.filteredPestRecords.isEmpty {
                Text("暂无虫害记录")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .frame(alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(dataManager.filteredPestRecords) { record in
                            PestDiseaseCard(record: record)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .id(dataManager.selectedCropFilter)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - 病害信息区域
struct DiseaseInfoSection: View {
    @ObservedObject var dataManager: InfoPanelDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack {
                HStack(spacing: 12) {
                    // 病害图标
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "leaf")
                            .font(.title2)
                            .foregroundColor(Color("primaryGreen"))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("病害信息")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("2小时前更新")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 记录数量
                Text("\(dataManager.filteredDiseaseRecords.count)条记录")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color("primaryGreen"))
                    .cornerRadius(99)
            }
            
            // 病害卡片列表
            if dataManager.filteredDiseaseRecords.isEmpty {
                Text("暂无病害记录")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .frame(alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(dataManager.filteredDiseaseRecords) { record in
                            PestDiseaseCard(record: record)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .id(dataManager.selectedCropFilter)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - 病虫害卡片（统一版本）
struct PestDiseaseCard: View {
    let record: PestDiseaseRecord
    
    var riskLevelColor: Color {
        switch record.riskLevel {
        case "高":
            return Color.red
        case "中":
            return Color.orange
        case "低":
            return Color("primaryGreen")
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图片和时间
            ZStack {
                // 图片
                Image(record.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
                
                // 时间标签（右下角）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(record.dateDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
            
            // 内容信息
            VStack(alignment: .leading, spacing: 6) {
                // 作物名称和风险等级
                HStack {
                    Text(record.cropName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(record.riskLevelText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(riskLevelColor)
                        .cornerRadius(12)
                }
                
                // 描述
                Text(record.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // 标签
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Array(record.tags.prefix(2)), id: \.label) { tag in
                            Text(tag.label)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    
                    if record.tags.count > 2 {
                        HStack(spacing: 6) {
                            ForEach(Array(record.tags.dropFirst(2)), id: \.label) { tag in
                                Text(tag.label)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // 治理按钮
                Button(action: {
                    print("添加治理日志: \(record.cropName)")
                }) {
                    Text("添加治理日志")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color("primaryGreen"))
                        .cornerRadius(8)
                }
            }
        }
        .frame(width: 280)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 趋势分析区域
struct TrendAnalysisSection: View {
    @ObservedObject var dataManager: InfoPanelDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("趋势分析")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color("primaryGreen"))
            }
            
            // 指标卡片
            if let trendData = dataManager.trendData {
                VStack(spacing: 12) {
                    ForEach(trendData.metrics) { metric in
                        TrendMetricCard(metric: metric)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 趋势指标卡片
struct TrendMetricCard: View {
    let metric: TrendMetric
    
    var metricColor: Color {
        switch metric.id {
        case "pest_activity":
            return Color.red
        case "disease_activity":
            return Color.orange
        case "crop_health":
            return Color("primaryGreen")
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(metric.weeklyChangeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Text("\(metric.currentValue)\(metric.unit)")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(metricColor)
                
                Image(systemName: metric.trend == "up" ? "arrow.up" : "arrow.down")
                    .font(.caption)
                    .foregroundColor(metricColor)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(9)
    }
}

// MARK: - 工作日志区域
struct WorkLogSection: View {
    @ObservedObject var dataManager: InfoPanelDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题
            HStack {
                Text("工作日志")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 机器狗筛选器
                if let workLogData = dataManager.workLogData {
                    SwiftUI.Menu(content: {
                        ForEach(workLogData.filter.options, id: \.self) { option in
                            Button(option) {
                                dataManager.selectedRobotFilter = option
                            }
                        }
                    }, label: {
                        HStack(spacing: 3) {
                            Text(dataManager.selectedRobotFilter)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("primaryGreen"))
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(Color("primaryGreen"))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(6)
                    })
                }
            }
            
            // 日志条目
            VStack(spacing: 16) {
                ForEach(dataManager.filteredWorkLogs) { log in
                    WorkLogCard(log: log)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 工作日志卡片
struct WorkLogCard: View {
    let log: WorkLog
    
    var iconColor: Color {
        switch log.type {
        case "拍摄":
            return Color.blue
        case "警告":
            return Color.orange
        case "红警告":
            return Color.red
        case "绿警告":
            return Color("primaryGreen")
        default:
            return Color.gray
        }
    }
    
    var iconName: String {
        switch log.type {
        case "拍摄":
            return "camera"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 6) {
                // 标题和时间
                HStack {
                    Text(log.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(log.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 描述
                Text(log.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                // 标签
                HStack(spacing: 10) {
                    Text(log.robotId)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(99)
                    
                    Text(log.taskType)
                        .font(.caption)
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(iconColor.opacity(0.1))
                        .cornerRadius(99)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(9)
    }
}

#Preview(traits:.landscapeRight) {
    InfoPanelView()
} 
