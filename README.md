# NGS6 LOOPER Controller

## English

### About This App

This is a simple mobile application designed to control the Drum Machine and Looper functions of the NUX Amp Academy (NGS-6) effects pedal. I created this app as a personal hobby project because I found it inconvenient to access these features on the device itself or through the official PC software, and the official mobile app lacks this functionality entirely.

This app provides a straightforward and easy-to-use interface to manage the drum machine and looper, making it much more convenient for daily practice and jamming.

![App Screenshot](Screenshot.jpg)

- **Official Product Page (CN):** [https://cn.nuxaudio.com/product/ampacademy/](https://cn.nuxaudio.com/product/ampacademy/)
- **Official Product Page (EN):** [https://nuxaudio.com/product/ampacademy/](https://nuxaudio.com/product/ampacademy/)

### Disclaimer

Please note that I am not a professional programmer, and this app was developed with significant assistance from AI. Therefore, it is provided "as is" and may have bugs or limitations. It serves its purpose but is not a polished, commercial product.

### Features

- **Drum Machine Control:**
    - Toggle the drum machine on/off.
    - Select from 67 different drum styles, with clear names displayed (e.g., "ROCK - Standard").
    - Adjust drum volume.
- **Advanced Looper Control:**
    - Standard controls: Record, Play, Stop, and Clear.
    - Multi-layer dubbing with Undo/Redo functionality for the last layer.
- **Real-time UI Sync:**
    - The app listens to MIDI feedback from the device to update the UI in real-time.
    - Button states (e.g., REC, PLAY, DUB) dynamically change and blink to reflect the pedal's actual status.
    - A dedicated status display shows the current looper state (e.g., "Recording Layer 1", "Playing", "Dubbing Layer 2").
- **Timer and Progress Bar:**
    - A timer is displayed during the initial recording to track the loop length.
    - A progress bar shows the current playback position of the loop.

### Future Improvements

- **State Persistence:** Save the last used drum style and other settings.
- **UI/UX Enhancements:** Further improve the user interface and overall user experience.
- **Error Handling:** Implement more robust error handling for device connection issues.

---

## 中文

### 关于此应用

这是一个简单的移动端应用，用于控制 NUX Amp Academy (NGS-6) 效果器的鼓机和乐句循环（LOOPER）功能。我开发这个应用纯粹是个人爱好，因为我发现直接在设备上或者通过官方电脑软件操作这些功能很不方便，而官方的移动应用则完全没有提供这些功能的控制界面。

这个应用提供了一个简单直观的界面来管理鼓机和乐句循环，为日常练习和演奏带来了极大的便利。

![应用截图](Screenshot.jpg)

- **官方产品页面（中文）:** [https://cn.nuxaudio.com/product/ampacademy/](https://cn.nuxaudio.com/product/ampacademy/)
- **官方产品页面（英文）:** [https://nuxaudio.com/product/ampacademy/](https://nuxaudio.com/product/ampacademy/)

### 免责声明

请注意，我不是一名专业的程序员，这个应用是在 AI 的大量协助下完成的。因此，本应用按“原样”提供，可能存在缺陷或功能限制。它能满足核心使用需求，但并非一个完善的商业产品。

### 功能

- **鼓机控制:**
    - 控制鼓机的开关。
    - 可选择多达67种不同的鼓机风格，并清晰显示风格名称（例如：“摇滚 - 标准”）。
    - 调节鼓机音量。
- **高级乐句循环控制:**
    - 基础控制：录音、播放、停止、清除。
    - 支持多层录音叠加，并可对最新一层进行撤销/重做（Undo/Redo）。
- **实时UI同步:**
    - 应用能够监听设备的MIDI回传信号，实时更新界面状态。
    - 按钮的状态（例如：REC, PLAY, DUB）会根据效果器的实际工作状态动态变化和闪烁。
    - 专门的状态显示区域会展示乐句循环的当前状态（如：“正在录制第1层”、“正在播放”、“正在叠加第2层”）。
- **计时器与进度条:**
    - 在录制第一层循环时，会显示计时器以记录乐句长度。
    - 播放时会显示进度条，直观展示当前播放位置。

### 未来计划

- **状态持久化:** 保存上次使用的鼓机风格和其他设置。
- **UI/UX 优化:** 进一步改进用户界面和整体用户体验。
- **异常处理:** 针对设备连接问题实现更完善的错误处理机制。