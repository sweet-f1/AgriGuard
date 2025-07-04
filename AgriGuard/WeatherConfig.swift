//
//  WeatherConfig.swift
//  AgriGuard
//
//  Created by AI Assistant on 2025/6/29.
//

import Foundation

// 和风天气JWT认证配置
struct WeatherConfig {
    // JWT认证信息（安全推荐）
    static let projectId = "2NKPCH532D"    // 从控制台获取的项目ID
    static let keyId = "CF5AJ9UXB3"            // 从控制台获取的凭据ID
    
    // Ed25519私钥（PEM格式）
    // TODO: 私钥安全存储，不直接硬编码在代码中
    static let privateKey = """
    -----BEGIN PRIVATE KEY-----
    MC4CAQAwBQYDK2VwBCIEIAmyjsrl15IggJUobVJPCluudDAT8bWWt5+jdHeZAhhw
    -----END PRIVATE KEY-----
    """
    
    // 默认位置ID（北京）
    static let defaultLocationId = "101010100"
    
    // 获取配置好的WeatherService实例
    static func createWeatherService() -> WeatherService {
        if !privateKey.contains("YOUR_") && !keyId.contains("YOUR_") && !projectId.contains("YOUR_") {
            // 使用JWT认证
            return WeatherService(
                privateKey: privateKey,
                keyId: keyId,
                projectId: projectId
            )
        } else {
            // 未配置JWT信息，返回默认实例
            print("⚠️ 请在WeatherConfig.swift中配置JWT认证信息")
            return WeatherService()
        }
    }
}

// MARK: - 使用说明
/*
 
 ## 🚀 JWT认证配置指南
 
 ### 步骤1: 注册和风天气开发者账号
 前往：https://dev.qweather.com/ 注册账号

 ### 步骤2: 生成Ed25519密钥对
 在终端运行以下命令：
 ```bash
 openssl genpkey -algorithm ED25519 -out ed25519-private.pem \
 && openssl pkey -pubout -in ed25519-private.pem > ed25519-public.pem
 ```

 ### 步骤3: 上传公钥到和风天气控制台
 1. 在控制台-项目管理中点击"添加凭据"
 2. 选择"JSON Web Token"认证方式
 3. 输入凭据名称（如：AgriGuard-JWT）
 4. 打开 `ed25519-public.pem` 文件，复制全部内容到公钥文本框
 5. 点击保存，记录下显示的：
    - **项目ID** (projectId)
    - **凭据ID** (keyId)

 ### 步骤4: 配置应用
 将以下信息填入上面的配置：
 ```swift
 static let projectId = "你的项目ID"      // 例如：HE2309281234567890
 static let keyId = "你的凭据ID"          // 例如：ABCD1234EFGH5678
 static let privateKey = """
 -----BEGIN PRIVATE KEY-----
 你的ed25519-private.pem文件的完整内容
 -----END PRIVATE KEY-----
 """
 ```

 ### 步骤5: 验证配置
 1. 运行应用
 2. 点击导航栏右上角的天气图标
 3. 查看Xcode控制台，成功的日志应该显示：
    ```
    开始生成JWT token...
    ✅ 私钥解析成功，长度: 32 字节
    ✅ Ed25519私钥加载成功
    ✅ JWT生成成功
    ✅ 使用JWT认证
    API状态码: 200
    ✅ 天气数据获取成功
    ```

 ## 📍 配置默认位置
 默认使用北京的位置ID "101010100"，你可以：
 1. 在和风天气官网查询其他城市的位置ID
 2. 修改 `defaultLocationId` 的值

 ## ⚠️ 安全注意事项
 - 私钥应该安全存储，实际应用中考虑使用Keychain
 - 不要将包含真实密钥的代码提交到公共代码仓库
 - 建议使用环境变量或配置文件管理敏感信息
 - 可以设置 .gitignore 忽略包含真实配置的文件

 ## 🔧 常见问题
 - **401认证失败** → 检查项目ID、密钥ID和私钥是否正确
 - **私钥解析失败** → 确保完整复制私钥内容，包括头尾标记
 - **网络错误** → 检查网络连接和和风天气服务状态
 
 */ 
