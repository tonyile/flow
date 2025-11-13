# App Store 提交流程清单（时光流水）

本清单覆盖 App Store Connect 要求：隐私政策 URL、选择构建版本、App 隐私问卷、定价与内容版权信息。

## 1. 隐私政策 URL（App 信息 > App 隐私）
- 选项 A：将仓库中的 `PRIVACY_POLICY.md` 发布到公开页面（例如 GitHub Pages、Notion、个人网站）。
  - GitHub Pages（示例）：
    1) 新建仓库 `privacy`，将 `PRIVACY_POLICY.md` 放入根目录并改名为 `index.md`
    2) 打开仓库设置 > Pages > 选择 `Deploy from a branch` 并启用
    3) 获得公开 URL，如 `https://<yourname>.github.io/privacy/`
- 选项 B：将内容复制到您的官网页面，获取稳定 URL。
- 完成后，在 App Store Connect 的“App 信息”中填写隐私政策 URL。

## 2. 选择构建版本（提交构建）
- 使用 Xcode Organizer：
  1) 选择 `Any iOS Device (arm64)` 作为运行目标
  2) Product > Archive（Release）
  3) Organizer > Distribute App > App Store Connect > Upload
  4) 上传成功后，稍等几分钟，回到 App Store Connect 的“TestFlight/活动”，选择构建并将其关联到版本
- 使用命令行（如需）：
  ```bash
  # 归档（会使用项目自动签名设置；首次可能需要 Xcode 登录）
  xcodebuild -project "/Users/fantast/时光流水/日常安排.xcodeproj" \
    -scheme "时光流水" -configuration Release -sdk iphoneos \
    -archivePath "/Users/fantast/时光流水/build/Archive/时光流水.xcarchive" \
    -allowProvisioningUpdates archive

  # 导出 IPA（使用已存在的 ExportOptions.plist）
  xcodebuild -exportArchive \
    -archivePath "/Users/fantast/时光流水/build/Archive/时光流水.xcarchive" \
    -exportPath "/Users/fantast/时光流水/build/IPA" \
    -exportOptionsPlist "/Users/fantast/时光流水/ExportOptions.plist"
  ```
  - 上传可使用 Xcode Organizer 或 Transporter（需要 Apple ID 和 App 专用密码）。

## 3. App 隐私问卷（App 隐私 > 提供相关信息）
- 跟据当前代码特性（仅供参考，请根据实际业务确认）：
  - 位置信息：不主动采集；若仅手动选择城市用于天气展示，可标注为“收集（非精确位置/城市）”，用途为“应用功能”，不用于跟踪。
  - 联系信息：不收集（姓名、邮箱、电话号码）。
  - 标识符：不收集广告标识符；不进行跨应用跟踪。
  - 诊断：不接入第三方统计；若仅系统崩溃日志，可标注为“收集诊断（匿名）”，仅用于提升稳定性，不用于跟踪。
  - 支付与购买：不涉及（如无内购）。
  - 追踪：不进行“跨网站/跨应用追踪”。
- 数据是否“与用户关联”：若仅在本地或 iCloud 中与用户账户绑定但不用于识别其他服务，可按不关联处理；如存在明确用户标识与服务绑定，请按关联选择。

## 4. 定价与可用性
- 若为免费：选择价格等级 `免费（Tier 0）`
- 确认上架区域（所有国家或选定国家/地区）

## 5. 内容版权信息（App 信息 > 内容版权）
- 若所有内容均为原创或已获授权：选择“我拥有此 App 中所有内容的必要权利”并简要说明。
- 若使用第三方素材（图标、音效、天气数据等）：请确保已获得授权并在此处说明来源与许可。

## 6. 提交审核前自查
- [ ] 隐私政策 URL 已填写且可访问
- [ ] 版本信息（描述、关键词、截图、支持设备）完整
- [ ] 构建版本已上传并在“选择构建版本”中可选中
- [ ] App 隐私问卷已全部填完并保存
- [ ] 定价与可用性已设置
- [ ] 内容版权信息已填写

---
如需，我可以将 `PRIVACY_POLICY.md` 内容转换为 HTML 并生成一个简易静态页，以便你托管在 GitHub Pages 或个人网站。