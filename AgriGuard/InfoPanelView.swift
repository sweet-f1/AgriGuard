//
//  InfoPanelView.swift
//  AgriGuard
//
//  Created by mart S on 2025/6/29.
//

import SwiftUI
import Foundation
import Combine

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
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    // 左侧：作物信息
                    CropInfoSection(dataManager: dataManager)
                        .frame(width: 558)
                    
                    // 右侧：趋势分析和工作日志
                    VStack(spacing: 24) {
                        TrendAnalysisSection(dataManager: dataManager)
                        WorkLogSection(dataManager: dataManager)
                    }
                    .frame(width: 324)
                }
                .padding(24)
            }
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
                        Button("水稻") { dataManager.selectedCropFilter = "水稻" }
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
            
            // 病害信息区域
            DiseaseInfoSection(dataManager: dataManager)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
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
            .padding(.horizontal, 16)
            
            // 虫害卡片列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(dataManager.filteredPestRecords) { record in
                        PestDiseaseCard(record: record)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
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
            .padding(.horizontal, 16)
            
            // 病害卡片列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(dataManager.filteredDiseaseRecords) { record in
                        PestDiseaseCard(record: record)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - 病虫害卡片
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
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // 图片
                    Image(record.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 271)
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            
            // 内容信息
            VStack(alignment: .leading, spacing: 6) {
                // 作物名称和风险等级
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(record.cropName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Text(record.riskLevelText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(riskLevelColor)
                        .cornerRadius(100)
                }
                
                // 描述
                Text(record.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                // 标签
                FlowLayout(spacing: 14) {
                    ForEach(record.tags, id: \.label) { tag in
                        Text(tag.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(100)
                    }
                }
                
                // 治理按钮
                Button(action: {
                    // 添加治理日志
                }) {
                    Text("添加治理日志")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color("primaryGreen"))
                        .cornerRadius(9)
                }
            }
        }
        .frame(width: 380)
        .padding(16)
        .background(Color.white)
        .cornerRadius(9)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 自定义流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var bounds = CGSize.zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            bounds.width = maxWidth
            bounds.height = y + lineHeight
        }
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
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
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
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
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
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 8) {
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
        .background(Color.white)
        .cornerRadius(9)
    }
}

#Preview(traits:.landscapeRight) {
    InfoPanelView()
} 
