# BabyTrip 调试运行手册

## 前置准备

### 1. 开发环境
- **Xcode**: 需要 Xcode 15 或更高版本（因为用了 SwiftUI 新特性）
  - App Store 直接更新到最新版就好
- **iOS 模拟器**: iOS 17+ 或者用真机调试
- **watchOS 模拟器**: watchOS 10+，如果要测试手表版

### 2. 获取 OpenWeatherMap API Key

项目使用免费的 OpenWeatherMap API 获取天气数据，需要你自己申请：

1. 打开 https://openweathermap.org/ 注册账号（免费）
2. 登录后进入 API Keys 页面：https://home.openweathermap.org/api_keys
3. 复制你的 `API key`
4. 打开项目中的 `BabyTrip/BabyTrip/Info.plist`
5. 找到 `OpenWeatherAPIKey` 这一行，把 `YOUR_API_KEY_HERE` 替换成你刚才复制的 key
6. 同样在 `BabyTripWatch/Info.plist` 也替换一遍（因为watchOS App也要请求）

> 免费额度足够 MVP 开发测试用了，每分钟 60 次调用，完全够用。

---

## 运行步骤

### 1. 拉代码打开项目

```bash
cd /Users/lunzi/.openclaw/workspace/haojian
git pull
open BabyTrip/BabyTrip.xcodeproj
```

### 2. 选择运行目标

- **iPhone 版**: 选择一个 iOS 17+ 模拟器或者你的真机
- **watchOS 版**: Xcode 顶部菜单 → `Product` → `Scheme` → `BabyTripWatch`，然后选 watchOS 模拟器

### 3. 编译运行

点击左上角 ▶️ 按钮（或者 `Cmd + R`），等待编译完成。

---

## 首次使用流程

1. App 启动后会进入**设置向导**
   - 选择宝宝的出生日期 → 自动计算月龄
   - 同意定位权限 → 自动获取当前城市天气
   - 如果定位失败，可以手动选择城市

2. 进入主页后就能看到结论了
   - 顶部大字：适合外出 / 谨慎外出 / 不建议外出
   - 下方列出原因（比如"紫外线过高"、"温度过低"）
   - 最底显示各项环境数据：温度、紫外线、AQI、风速

3. **刷新数据**: 下拉主页就能刷新天气数据

4. **修改设置**: 点击右上角齿轮图标 → 进入设置页，可以改宝宝出生日期、切换城市

5. **watchOS 版**: 在手表上直接看结论和评分，快速查看

---

## 常见问题排查

### 问题1: 看不到天气数据，一直加载

**排查**：
- 检查 API Key 是否填对了（Info.plist 两处都要改）
- 去 OpenWeatherMap 网站看看你的 API Key 是否激活（新注册可能需要等几分钟生效）
- 检查网络连接

### 问题2: 定位不到我的位置

**排查**：
- 检查定位权限是否开启：设置 → 隐私与安全性 → 定位服务 → 找到 BabyTrip → 打开
- 如果在模拟器，可以模拟位置：Xcode 模拟器 → Features → Location 选择一个城市

### 问题3: 紫外线指数一直是 0？

**原因**：
OpenWeatherMap 免费版的紫外线指数需要用 One Call API，项目已经处理好了，如果还是 0 说明你的 API 权限不够，可以：
1. 确认你订阅了 One Call API（免费版也能⽤）
2. 如果还是不行，不影响核心功能，紫外线会默认按安全处理

### 问题4: AQI 空气质量看不到数据？

**原因**：
AQI 数据来自 Air Pollution API，也是 OpenWeatherMap 提供的，免费版支持，如果没数据会显示 "未知"，不影响其他因素的判断。

### 问题5: 编译错误 "No such module"

**解决**：
- 项目没有用第三方 CocoaPods，都是原生框架，不存在这个问题
- 如果真出了，试试 Xcode → `Cmd + Shift + K` 清理缓存，重新编译

---

## 核心逻辑调试

如果你想改判断规则，去这里：

```
BabyTripShared/RiskEvaluation/RiskEvaluator.swift
```

这里就是完整的 MVP 判断引擎，所有阈值都在这儿，改了重新编译就行。

---

## 提交代码

改完代码想提交到 GitHub：

```bash
cd /Users/lunzi/.openclaw/workspace/haojian
git add .
git commit -m "描述你改了啥"
git push
```

token 已经配置好了，直接推就行，不用再输密码。

---

祝你调试顺利！🎯
