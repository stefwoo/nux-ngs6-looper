# MIDI控制器APP项目文档

## 项目目标
开发一个通过USB发送MIDI信号的Flutter安卓APP，具有以下功能：
- 4个可配置按钮，点击发送MIDI信号
- 按钮状态反馈（颜色变化）
- USB MIDI设备识别和选择
- 配置持久化存储

## 技术方案

### 技术栈
- Flutter 3.x
- 插件：
  - flutter_libusb: USB通信
  - midi_utils: MIDI协议处理
  - shared_preferences: 配置存储

### 数据模型
```dart
class MidiDevice {
  String id;
  String name;
  //...
}

class MidiButtonConfig {
  String name;
  String midiCommand; 
  Color activeColor;
  //...
}
```

### 架构设计
1. **设备管理模块**
   - USB设备枚举
   - MIDI设备识别
   - 设备连接管理

2. **配置管理模块**
   - 加载/保存设备配置
   - 按钮配置管理
   - 使用shared_preferences持久化

3. **UI模块**
   - 设备选择下拉菜单
   - 4个可配置MIDI按钮
   - 配置编辑界面

4. **MIDI模块**
   - MIDI信号构建
   - USB MIDI发送

## 实现计划

### 第一阶段：基础架构
1. 添加依赖
2. 实现设备枚举
3. 创建配置管理

### 第二阶段：核心功能 
1. 实现MIDI发送
2. 构建基础UI
3. 连接UI和功能

### 第三阶段：完善功能
1. 添加配置编辑
2. 完善状态反馈
3. 测试和调试

## 风险与应对
1. **USB兼容性问题**
   - 方案：测试多种设备，提供错误处理

2. **MIDI协议差异**
   - 方案：使用标准MIDI协议实现
