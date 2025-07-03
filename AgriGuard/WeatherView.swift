//
//  WeatherView.swift
//  AgriGuard
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import CryptoKit
import Combine

// Base64URL编码扩展
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// 天气数据模型
struct WeatherData: Codable {
    let now: CurrentWeather
    let location: [LocationData]?
}

struct CurrentWeather: Codable {
    let obsTime: String     // 观测时间
    let temp: String        // 温度
    let feelsLike: String   // 体感温度
    let icon: String        // 天气图标代码
    let text: String        // 天气描述
    let wind360: String     // 风向角度
    let windDir: String     // 风向
    let windScale: String   // 风力等级
    let windSpeed: String   // 风速
    let humidity: String    // 相对湿度
    let precip: String      // 小时降水量
    let pressure: String    // 大气压强
    let vis: String         // 能见度
    let cloud: String       // 云量
    let dew: String         // 露点温度
}

struct LocationData: Codable {
    let name: String        // 地区名称
    let id: String          // 地区ID
    let lat: String         // 纬度
    let lon: String         // 经度
    let adm2: String        // 行政区划2
    let adm1: String        // 行政区划1
    let country: String     // 国家
    let tz: String          // 时区
    let utcOffset: String   // UTC时间偏移
    let isDst: String       // 是否夏令时
    let type: String        // 地区类型
    let rank: String        // 地区评分
    let fxLink: String      // 链接
}

// 和风天气API响应模型
struct QWeatherResponse: Codable {
    let code: String
    let updateTime: String
    let fxLink: String
    let now: CurrentWeather
}

struct QWeatherLocationResponse: Codable {
    let code: String
    let location: [LocationData]
}

// 24小时预报数据模型
struct HourlyForecast: Codable {
    let fxTime: String      // 预报时间
    let temp: String        // 温度
    let icon: String        // 天气图标代码
    let text: String        // 天气描述
    let wind360: String     // 风向角度
    let windDir: String     // 风向
    let windScale: String   // 风力等级
    let windSpeed: String   // 风速
    let humidity: String    // 相对湿度
    let pop: String         // 降水概率
    let precip: String      // 降水量
    let pressure: String    // 大气压强
    let cloud: String       // 云量
    let dew: String         // 露点温度
}

struct QWeatherHourlyResponse: Codable {
    let code: String
    let updateTime: String
    let fxLink: String
    let hourly: [HourlyForecast]
}

// 7日预报数据模型
struct DailyForecast: Codable {
    let fxDate: String      // 预报日期
    let sunrise: String     // 日出时间
    let sunset: String      // 日落时间
    let moonrise: String    // 月升时间
    let moonset: String     // 月落时间
    let moonPhase: String   // 月相名称
    let moonPhaseIcon: String // 月相图标
    let tempMax: String     // 最高温度
    let tempMin: String     // 最低温度
    let iconDay: String     // 白天天气图标代码
    let textDay: String     // 白天天气描述
    let iconNight: String   // 夜间天气图标代码
    let textNight: String   // 夜间天气描述
    let wind360Day: String  // 白天风向角度
    let windDirDay: String  // 白天风向
    let windScaleDay: String // 白天风力等级
    let windSpeedDay: String // 白天风速
    let wind360Night: String // 夜间风向角度
    let windDirNight: String // 夜间风向
    let windScaleNight: String // 夜间风力等级
    let windSpeedNight: String // 夜间风速
    let humidity: String    // 相对湿度
    let precip: String      // 降水量
    let pressure: String    // 大气压强
    let vis: String         // 能见度
    let cloud: String       // 云量
    let uvIndex: String     // 紫外线强度指数
}

struct QWeatherDailyResponse: Codable {
    let code: String
    let updateTime: String
    let fxLink: String
    let daily: [DailyForecast]
}

// JWT生成器
class QWeatherJWTGenerator {
    private let privateKey: String
    private let keyId: String
    private let projectId: String
    
    init(privateKey: String, keyId: String, projectId: String) {
        self.privateKey = privateKey
        self.keyId = keyId
        self.projectId = projectId
    }
    
    func generateJWT() -> String? {
        print("开始生成JWT token...")
        print("项目ID: \(projectId)")
        print("密钥ID: \(keyId)")
        
        do {
            // 解析私钥
            guard let privateKeyData = parsePrivateKey(privateKey) else {
                print("❌ 私钥解析失败，请检查privateKey格式")
                return nil
            }
            print("✅ 私钥解析成功，长度: \(privateKeyData.count) 字节")
            
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            print("✅ Ed25519私钥加载成功")
            
            // 创建JWT header
            let header = ["alg": "EdDSA", "kid": keyId]
            let headerData = try JSONSerialization.data(withJSONObject: header)
            let headerBase64 = headerData.base64URLEncodedString()
            
            // 创建JWT payload
            let now = Int(Date().timeIntervalSince1970)
            let payload: [String: Any] = [
                "sub": projectId,
                "iat": now - 30,  // 提前30秒，避免时间误差
                "exp": now + 900  // 15分钟后过期
            ]
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            let payloadBase64 = payloadData.base64URLEncodedString()
            
            // 创建签名消息
            let message = "\(headerBase64).\(payloadBase64)"
            let messageData = Data(message.utf8)
            
            // 使用Ed25519签名
            let signature = try signingKey.signature(for: messageData)
            let signatureBase64 = Data(signature).base64URLEncodedString()
            
            let jwt = "\(message).\(signatureBase64)"
            print("✅ JWT生成成功，长度: \(jwt.count)")
            
            return jwt
            
        } catch {
            print("❌ JWT生成失败: \(error)")
            return nil
        }
    }
    
    private func parsePrivateKey(_ pemString: String) -> Data? {
        // 移除PEM格式的头部和尾部，提取Base64编码的密钥数据
        let lines = pemString.components(separatedBy: .newlines)
        let keyLines = lines.filter { line in
            !line.contains("-----BEGIN") && !line.contains("-----END") && !line.trimmingCharacters(in: .whitespaces).isEmpty
        }
        
        let base64String = keyLines.joined()
        guard let keyData = Data(base64Encoded: base64String) else {
            return nil
        }
        
        // Ed25519私钥的原始数据通常是32字节
        // 需要从DER编码中提取原始密钥数据
        return extractEd25519RawKey(from: keyData)
    }
    
    private func extractEd25519RawKey(from derData: Data) -> Data? {
        // Ed25519 DER编码的私钥格式：
        // SEQUENCE (48 bytes) {
        //   INTEGER version (1 byte)
        //   SEQUENCE algorithm {
        //     OBJECT IDENTIFIER Ed25519
        //   }
        //   OCTET STRING privateKey (34 bytes) {
        //     OCTET STRING rawKey (32 bytes)
        //   }
        // }
        
        // 简化的DER解析，查找32字节的密钥数据
        let keyData = derData
        
        // 寻找32字节的Ed25519原始密钥
        for i in 0..<(keyData.count - 32) {
            let candidate = keyData.subdata(in: i..<(i + 32))
            // 简单验证：Ed25519私钥的第一个字节通常在某个范围内
            if candidate.count == 32 {
                // 尝试最后的32字节（通常是DER编码中的实际密钥部分）
                if i >= keyData.count - 32 {
                    return candidate
                }
            }
        }
        
        // 如果找不到，尝试倒数32字节
        if keyData.count >= 32 {
            return keyData.suffix(32)
        }
        
        return nil
    }
}

// 天气服务
@MainActor
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let jwtGenerator: QWeatherJWTGenerator?
    private let baseURL = "https://mu63yvq2q6.re.qweatherapi.com/v7"
    
    init(privateKey: String = "", keyId: String = "", projectId: String = "") {
        if !privateKey.isEmpty && !keyId.isEmpty && !projectId.isEmpty {
            self.jwtGenerator = QWeatherJWTGenerator(privateKey: privateKey, keyId: keyId, projectId: projectId)
        } else {
            self.jwtGenerator = nil
        }
    }
    
    func fetchCurrentWeather(location: String = "101010100") { // 默认北京
        isLoading = true
        errorMessage = nil
        
        // 同时获取当前天气、24小时预报和7日预报
        Task {
            await withTaskGroup(of: Void.self) { group in
                // 获取当前天气
                group.addTask {
                    await self.fetchNowWeather(location: location)
                }
                
                // 获取24小时预报
                group.addTask {
                    await self.fetchHourlyForecast(location: location)
                }
                
                // 获取7日预报
                group.addTask {
                    await self.fetchDailyForecast(location: location)
                }
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // 基于经纬度获取天气
    func fetchWeatherForCoordinate(latitude: Double, longitude: Double) {
        let locationString = "\(longitude),\(latitude)" // 和风天气API格式：经度,纬度
        print("🌍 获取位置天气: 纬度=\(latitude), 经度=\(longitude)")
        fetchCurrentWeather(location: locationString)
    }
    
    private func fetchNowWeather(location: String) async {
        guard let jwtGenerator = jwtGenerator, let jwt = jwtGenerator.generateJWT() else {
            await MainActor.run {
                self.errorMessage = "请在WeatherConfig.swift中配置完整的JWT认证信息（项目ID、密钥ID、私钥）"
            }
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/weather/now")!
        urlComponents.queryItems = [URLQueryItem(name: "location", value: location)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let weatherResponse = try JSONDecoder().decode(QWeatherResponse.self, from: data)
            
            if weatherResponse.code == "200" {
                await MainActor.run {
                    self.currentWeather = weatherResponse.now
                }
                print("✅ 当前天气数据获取成功")
                print("🌤 天气代码: \(weatherResponse.now.icon), 天气描述: \(weatherResponse.now.text)")
            } else {
                await MainActor.run {
                    let errorMsg = self.getErrorMessage(for: weatherResponse.code)
                    self.errorMessage = "当前天气API错误: \(errorMsg) (代码: \(weatherResponse.code))"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "当前天气数据解析错误: \(error.localizedDescription)"
            }
            print("❌ 当前天气数据获取失败: \(error)")
        }
    }
    
    private func fetchHourlyForecast(location: String) async {
        guard let jwtGenerator = jwtGenerator, let jwt = jwtGenerator.generateJWT() else {
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/weather/24h")!
        urlComponents.queryItems = [URLQueryItem(name: "location", value: location)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let forecastResponse = try JSONDecoder().decode(QWeatherHourlyResponse.self, from: data)
            
            if forecastResponse.code == "200" {
                await MainActor.run {
                    self.hourlyForecast = forecastResponse.hourly // 取完整24小时数据
                }
                print("✅ 24小时预报数据获取成功，共\(forecastResponse.hourly.count)条")
            } else {
                print("❌ 24小时预报API错误: \(forecastResponse.code)")
            }
        } catch {
            print("❌ 24小时预报数据获取失败: \(error)")
        }
    }
    
    private func fetchDailyForecast(location: String) async {
        guard let jwtGenerator = jwtGenerator, let jwt = jwtGenerator.generateJWT() else {
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/weather/7d")!
        urlComponents.queryItems = [URLQueryItem(name: "location", value: location)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let forecastResponse = try JSONDecoder().decode(QWeatherDailyResponse.self, from: data)
            
            if forecastResponse.code == "200" {
                await MainActor.run {
                    self.dailyForecast = forecastResponse.daily // 取完整7天数据
                }
                print("✅ 7日预报数据获取成功，共\(forecastResponse.daily.count)天")
            } else {
                print("❌ 7日预报API错误: \(forecastResponse.code)")
            }
        } catch {
            print("❌ 7日预报数据获取失败: \(error)")
        }
    }
    
    private func getErrorMessage(for code: String) -> String {
        switch code {
        case "400":
            return "请求错误，请检查参数"
        case "401":
            return "认证失败，请检查API Key或JWT配置"
        case "402":
            return "超过访问次数限制"
        case "403":
            return "无访问权限，请检查账号状态"
        case "404":
            return "查询的数据不存在"
        case "429":
            return "超过限定的QPM"
        case "500":
            return "服务器内部错误"
        default:
            return "未知错误"
        }
    }
}

// 天气和头像组件
struct WeatherAvatarView: View {
    @ObservedObject var weatherService: WeatherService
    @Binding var showWeatherPopup: Bool
    let regionName: String
    
    private var weatherIconName: String {
        if let weather = weatherService.currentWeather {
            return weatherIconNameFor(code: weather.icon)
        }
        return "sun.max.fill"
    }
    
    private var temperatureText: String {
        if let weather = weatherService.currentWeather {
            return "\(weather.temp)℃"
        }
        return "24℃"
    }
    
    var body: some View {
        HStack(spacing: 13) {
            // 天气显示
            Button(action: {
                showWeatherPopup = true
            }) {
                HStack(spacing: 8) {
                    // 天气图标
                    Image(systemName: weatherIconName)
                        .symbolRenderingMode(.multicolor)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0.5, y: 0.5)
                        .font(.system(size: 14, weight: .medium))
                    
                    // 温度文字
                    Text(temperatureText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                )
            }
            .buttonStyle(.plain)
            
            // 通知图标
            Button(action: {
                // 通知逻辑
            }) {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "bell")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .regular))
                    )
            }
            .buttonStyle(.plain)
            
            // 用户头像
            Button(action: {
                // 用户菜单逻辑
            }) {
                Image("avatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func weatherIconNameFor(code: String) -> String {
        // 根据和风天气图标代码转换为SF Symbols
        switch code {
        // 晴天系列 (白天和夜间)
        case "100": return "sun.max.fill"                    // 晴 (白天)
        case "150": return "moon.stars.fill"                 // 晴 (夜间)
        
        // 多云系列 (白天和夜间)
        case "101": return "cloud.sun.fill"                 // 多云 (白天)
        case "102": return "cloud.sun.fill"                 // 少云 (白天)
        case "103": return "cloud.sun.fill"                 // 晴间多云 (白天)
        case "104": return "cloud.fill"                     // 阴
        case "151": return "cloud.moon.fill"                // 多云 (夜间)
        case "152": return "cloud.moon.fill"                // 少云 (夜间)
        case "153": return "cloud.moon.fill"                // 晴间多云 (夜间)
        
        // 雨系列 (白天和夜间)
        case "300": return "cloud.drizzle.fill"             // 阵雨 (白天)
        case "301": return "cloud.drizzle.fill"             // 强阵雨 (白天)
        case "302": return "cloud.bolt.rain.fill"           // 雷阵雨 (白天)
        case "303": return "cloud.bolt.rain.fill"           // 强雷阵雨 (白天)
        case "304": return "cloud.bolt.rain.fill"           // 雷阵雨伴有冰雹 (白天)
        case "305": return "cloud.rain.fill"                // 小雨
        case "306": return "cloud.rain.fill"                // 中雨
        case "307": return "cloud.rain.fill"                // 大雨
        case "308": return "cloud.heavyrain.fill"           // 极端降雨
        case "309": return "cloud.drizzle.fill"             // 毛毛雨/细雨
        case "310": return "cloud.heavyrain.fill"           // 暴雨
        case "311": return "cloud.heavyrain.fill"           // 大暴雨
        case "312": return "cloud.heavyrain.fill"           // 特大暴雨
        case "313": return "cloud.sleet.fill"               // 冻雨
        case "314", "315", "316", "317", "318": return "cloud.rain.fill" // 雨转换
        case "350": return "cloud.moon.rain.fill"           // 阵雨 (夜间)
        case "351": return "cloud.moon.rain.fill"           // 强阵雨 (夜间)
        case "399": return "cloud.rain.fill"                // 雨
        
        // 雪系列
        case "400": return "cloud.snow.fill"                // 小雪
        case "401": return "cloud.snow.fill"                // 中雪
        case "402": return "cloud.snow.fill"                // 大雪
        case "403": return "cloud.snow.fill"                // 暴雪
        case "404": return "cloud.sleet.fill"               // 雨夹雪
        case "405": return "cloud.sleet.fill"               // 雨雪天气
        case "406": return "cloud.sleet.fill"               // 阵雨夹雪
        case "407": return "cloud.sleet.fill"               // 阵雪
        case "408": return "cloud.snow.fill"                // 小雪转中雪
        case "409": return "cloud.snow.fill"                // 中雪转大雪
        case "410": return "cloud.snow.fill"                // 大雪转暴雪
        case "456": return "cloud.sleet.fill"               // 阵雨夹雪 (夜间)
        case "457": return "cloud.snow.fill"                // 阵雪 (夜间)
        case "499": return "cloud.snow.fill"                // 雪
        
        // 雾霾系列
        case "500": return "cloud.fog.fill"                 // 薄雾
        case "501": return "cloud.fog.fill"                 // 雾
        case "502": return "smoke.fill"                     // 霾
        case "503": return "smoke.fill"                     // 扬沙
        case "504": return "smoke.fill"                     // 浮尘
        case "507": return "smoke.fill"                     // 沙尘暴
        case "508": return "smoke.fill"                     // 强沙尘暴
        case "509": return "cloud.fog.fill"                 // 浓雾
        case "510": return "cloud.fog.fill"                 // 强浓雾
        case "511": return "cloud.fog.fill"                 // 中度霾
        case "512": return "smoke.fill"                     // 重度霾
        case "513": return "smoke.fill"                     // 严重霾
        case "514": return "cloud.fog.fill"                 // 大雾
        case "515": return "cloud.fog.fill"                 // 特强浓雾
        
        // 其他天气
        case "900": return "thermometer.sun.fill"           // 热
        case "901": return "thermometer.snowflake"          // 冷
        case "999": return "questionmark.circle.fill"       // 未知
        
        default: 
            print("⚠️ 未知天气代码: \(code)")
            return "sun.max.fill"
        }
    }
    
    private func weatherIconColorFor(weather: CurrentWeather?) -> Color {
        guard let weather = weather else { return .orange }
        
        // 根据天气类型返回对应颜色
        switch weather.icon {
        case "100": return .orange // 晴天
        case "101", "102", "103": return .gray // 多云
        case "104": return .gray // 阴天
        case "150", "151", "152", "153": return .blue // 小雨
        case "300", "301", "302", "303", "304": return .blue // 阵雨
        case "305", "306", "307", "308", "309", "310", "311", "312", "313": return .blue // 大雨
        case "400", "401", "402", "403", "404", "405", "406", "407": return .white // 雪
        case "500", "501", "502", "503", "504", "507", "508": return .gray // 雾
        default: return .orange
        }
    }
}

// 天气弹窗组件
struct WeatherPopupView: View {
    @ObservedObject var weatherService: WeatherService
    @Binding var isPresented: Bool
    let regionName: String
    
    var body: some View {
        VStack(spacing: 0) {
            // 天气图片背景
            ZStack {
                AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?w=400&h=120&fit=crop")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .frame(width: 340, height: 120)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            .overlay(alignment: .topTrailing) {
                // 关闭按钮
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.black.opacity(0.3)))
                }
                .padding(12)
            }
            .overlay(alignment: .topLeading) {
                // 天气标题
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(regionName)天气")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("经度 120.08°E，纬度 30.31°N")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(16)
            }
            
            // 天气信息区域
            VStack(spacing: 16) {
                if weatherService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding()
                } else if let weather = weatherService.currentWeather {
                    // 主要天气信息
                    HStack(spacing: 16) {
                        // 天气图标和温度
                        VStack(spacing: 4) {
                            Image(systemName: weatherIconName(for: weather.icon))
                                .font(.system(size: 24, weight: .medium))
                                .symbolRenderingMode(.multicolor)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                                .frame(height: 24)
                            
                            Text("\(weather.temp)℃")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("温度")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 湿度
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.blue)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                                .frame(height: 24)
                            
                            Text("\(weather.humidity)%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("湿度")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 风速
                        VStack(spacing: 4) {
                            Image(systemName: "wind")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.gray)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                                .frame(height: 24)
                            
                            Text("\(weather.windSpeed)km/h")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("风速")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    
                    // 24小时预报标题
                    HStack {
                        Text("24小时预报")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // 24小时预报（可滑动）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 显示现在
                            VStack(spacing: 6) {
                                Image(systemName: weatherIconName(for: weather.icon))
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.multicolor)
                                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0.5, y: 0.5)
                                    .frame(height: 16)
                                
                                Text("\(weather.temp)℃")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("现在")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 55, height: 60) // 固定宽度与7日预报保持一致
                            
                            if weatherService.hourlyForecast.isEmpty {
                                // 显示加载中的占位符
                                ForEach(0..<4, id: \.self) { _ in
                                    VStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(height: 16)
                                        Text("--℃")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("--:--")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 55, height: 60)
                                }
                            } else {
                                // 显示完整24小时预报数据
                                ForEach(weatherService.hourlyForecast, id: \.fxTime) { forecast in
                                    VStack(spacing: 6) {
                                        Image(systemName: weatherIconName(for: forecast.icon))
                                            .font(.system(size: 16))
                                            .symbolRenderingMode(.multicolor)
                                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0.5, y: 0.5)
                                            .frame(height: 16)
                                        
                                        Text("\(forecast.temp)℃")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text(formatHourTime(forecast.fxTime))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 55, height: 60) // 固定宽度与7日预报保持一致
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 7日预报标题
                    HStack {
                        Text("7日预报")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // 7日预报（可滑动）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if weatherService.dailyForecast.isEmpty {
                                // 显示加载中的占位符
                                ForEach(0..<7, id: \.self) { index in
                                    VStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("--℃")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(index == 0 ? "今日" : index == 1 ? "明日" : "加载中")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 55, height: 70) // 固定宽度
                                }
                            } else {
                                // 显示完整7日预报数据
                                ForEach(Array(weatherService.dailyForecast.enumerated()), id: \.element.fxDate) { index, forecast in
                                    VStack(spacing: 6) {
                                        Image(systemName: weatherIconName(for: forecast.iconDay))
                                            .font(.system(size: 16))
                                            .symbolRenderingMode(.multicolor)
                                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0.5, y: 0.5)
                                            .frame(height: 16)
                                        
                                        VStack(spacing: 2) {
                                            Text("\(forecast.tempMax)℃")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("\(forecast.tempMin)℃")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(formatDayText(for: index, date: forecast.fxDate))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 55, height: 70) // 固定宽度确保列表整齐
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                } else if let error = weatherService.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        Text("获取天气信息失败")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("重试") {
                            weatherService.fetchCurrentWeather()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                }
            }
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
        }
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            if weatherService.currentWeather == nil {
                weatherService.fetchCurrentWeather()
            }
        }
    }
    
    private func weatherIconName(for code: String) -> String {
        // 根据和风天气图标代码转换为SF Symbols
        switch code {
        // 晴天系列 (白天和夜间)
        case "100": return "sun.max.fill"                    // 晴 (白天)
        case "150": return "moon.stars.fill"                 // 晴 (夜间)
        
        // 多云系列 (白天和夜间)
        case "101": return "cloud.sun.fill"                 // 多云 (白天)
        case "102": return "cloud.sun.fill"                 // 少云 (白天)
        case "103": return "cloud.sun.fill"                 // 晴间多云 (白天)
        case "104": return "cloud.fill"                     // 阴
        case "151": return "cloud.moon.fill"                // 多云 (夜间)
        case "152": return "cloud.moon.fill"                // 少云 (夜间)
        case "153": return "cloud.moon.fill"                // 晴间多云 (夜间)
        
        // 雨系列 (白天和夜间)
        case "300": return "cloud.drizzle.fill"             // 阵雨 (白天)
        case "301": return "cloud.drizzle.fill"             // 强阵雨 (白天)
        case "302": return "cloud.bolt.rain.fill"           // 雷阵雨 (白天)
        case "303": return "cloud.bolt.rain.fill"           // 强雷阵雨 (白天)
        case "304": return "cloud.bolt.rain.fill"           // 雷阵雨伴有冰雹 (白天)
        case "305": return "cloud.rain.fill"                // 小雨
        case "306": return "cloud.rain.fill"                // 中雨
        case "307": return "cloud.rain.fill"                // 大雨
        case "308": return "cloud.heavyrain.fill"           // 极端降雨
        case "309": return "cloud.drizzle.fill"             // 毛毛雨/细雨
        case "310": return "cloud.heavyrain.fill"           // 暴雨
        case "311": return "cloud.heavyrain.fill"           // 大暴雨
        case "312": return "cloud.heavyrain.fill"           // 特大暴雨
        case "313": return "cloud.sleet.fill"               // 冻雨
        case "314", "315", "316", "317", "318": return "cloud.rain.fill" // 雨转换
        case "350": return "cloud.moon.rain.fill"           // 阵雨 (夜间)
        case "351": return "cloud.moon.rain.fill"           // 强阵雨 (夜间)
        case "399": return "cloud.rain.fill"                // 雨
        
        // 雪系列
        case "400": return "cloud.snow.fill"                // 小雪
        case "401": return "cloud.snow.fill"                // 中雪
        case "402": return "cloud.snow.fill"                // 大雪
        case "403": return "cloud.snow.fill"                // 暴雪
        case "404": return "cloud.sleet.fill"               // 雨夹雪
        case "405": return "cloud.sleet.fill"               // 雨雪天气
        case "406": return "cloud.sleet.fill"               // 阵雨夹雪
        case "407": return "cloud.sleet.fill"               // 阵雪
        case "408": return "cloud.snow.fill"                // 小雪转中雪
        case "409": return "cloud.snow.fill"                // 中雪转大雪
        case "410": return "cloud.snow.fill"                // 大雪转暴雪
        case "456": return "cloud.sleet.fill"               // 阵雨夹雪 (夜间)
        case "457": return "cloud.snow.fill"                // 阵雪 (夜间)
        case "499": return "cloud.snow.fill"                // 雪
        
        // 雾霾系列
        case "500": return "cloud.fog.fill"                 // 薄雾
        case "501": return "cloud.fog.fill"                 // 雾
        case "502": return "smoke.fill"                     // 霾
        case "503": return "smoke.fill"                     // 扬沙
        case "504": return "smoke.fill"                     // 浮尘
        case "507": return "smoke.fill"                     // 沙尘暴
        case "508": return "smoke.fill"                     // 强沙尘暴
        case "509": return "cloud.fog.fill"                 // 浓雾
        case "510": return "cloud.fog.fill"                 // 强浓雾
        case "511": return "cloud.fog.fill"                 // 中度霾
        case "512": return "smoke.fill"                     // 重度霾
        case "513": return "smoke.fill"                     // 严重霾
        case "514": return "cloud.fog.fill"                 // 大雾
        case "515": return "cloud.fog.fill"                 // 特强浓雾
        
        // 其他天气
        case "900": return "thermometer.sun.fill"           // 热
        case "901": return "thermometer.snowflake"          // 冷
        case "999": return "questionmark.circle.fill"       // 未知
        
        default: 
            print("⚠️ 未知天气代码: \(code)")
            return "sun.max.fill"
        }
    }
    
    private func weatherIconColor(for code: String) -> Color {
        // 根据天气类型返回对应颜色
        switch code {
        // 晴天系列 (白天和夜间)
        case "100": return .orange                          // 晴天 (白天)
        case "150": return .yellow                          // 晴天 (夜间)
        
        // 多云系列 (白天和夜间)
        case "101", "102", "103": return .gray              // 多云、少云、晴间多云 (白天)
        case "104": return .gray                            // 阴天
        case "151", "152", "153": return .gray              // 多云、少云、晴间多云 (夜间)
        
        // 雨系列 (白天和夜间)
        case "300", "301": return .blue                     // 阵雨
        case "302", "303", "304": return .purple            // 雷阵雨
        case "305", "306", "307": return .blue              // 小雨、中雨、大雨
        case "308": return .blue                            // 极端降雨
        case "309": return .blue                            // 毛毛雨
        case "310", "311", "312": return .blue              // 暴雨系列
        case "313": return .cyan                            // 冻雨
        case "314", "315", "316", "317", "318": return .blue // 雨转换
        case "350", "351": return .blue                     // 阵雨 (夜间)
        case "399": return .blue                            // 雨
        
        // 雪系列
        case "400", "401", "402", "403": return .white      // 各种雪
        case "404", "405", "406", "407": return .cyan       // 雨夹雪、阵雪
        case "408", "409", "410": return .white             // 雪转换
        case "456", "457": return .cyan                     // 夜间雨夹雪、阵雪
        case "499": return .white                           // 雪
        
        // 雾霾系列
        case "500", "501": return .gray                     // 薄雾、雾
        case "502": return .brown                           // 霾
        case "503", "504": return .brown                    // 扬沙、浮尘
        case "507", "508": return .brown                    // 沙尘暴
        case "509", "510": return .gray                     // 浓雾
        case "511": return .brown                           // 中度霾
        case "512", "513": return .brown                    // 重度霾、严重霾
        case "514", "515": return .gray                     // 大雾、特强浓雾
        
        // 其他天气
        case "900": return .red                             // 热
        case "901": return .blue                            // 冷
        case "999": return .gray                            // 未知
        
        default: return .orange
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: String(timeString.prefix(16))) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return timeString
    }
    
    private func formatHourTime(_ timeString: String) -> String {
        // 和风天气API返回的时间格式通常是：2024-01-27T13:00+08:00
        let formatter = DateFormatter()
        
        // 尝试完整格式
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"
        if let date = formatter.date(from: timeString) {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "HH:mm"
            return hourFormatter.string(from: date)
        }
        
        // 尝试带时区的格式
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm+HH:mm"
        if let date = formatter.date(from: timeString) {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "HH:mm"
            return hourFormatter.string(from: date)
        }
        
        // 尝试简化格式
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: String(timeString.prefix(16))) {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "HH:mm"
            return hourFormatter.string(from: date)
        }
        
        // 如果都失败了，尝试直接提取小时分钟
        if let timeRange = timeString.range(of: "T(\\d{2}:\\d{2})", options: .regularExpression) {
            let timeStr = String(timeString[timeRange])
            return String(timeStr.dropFirst()) // 去掉 'T'
        }
        
        print("⚠️ 无法解析时间格式: \(timeString)")
        return timeString
    }
    
    private func formatDayText(for index: Int, date: String) -> String {
        if index == 0 {
            return "今日"
        } else if index == 1 {
            return "明日"
        }
        
        // 解析日期并格式化为星期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: date) {
            let weekFormatter = DateFormatter()
            weekFormatter.locale = Locale(identifier: "zh_CN")
            weekFormatter.dateFormat = "E"
            return weekFormatter.string(from: date)
        }
        
        return "预报"
    }
}


