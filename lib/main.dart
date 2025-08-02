import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'models/midi_device.dart';
import 'services/midi_service.dart';
import 'widgets/drum_controls.dart';
import 'widgets/looper_status.dart';
import 'widgets/looper_controls.dart';
import 'widgets/main_content.dart';
import 'widgets/midi_status_widget.dart';

void main() => runApp(const MidiControllerApp());

class MidiControllerApp extends StatelessWidget {
  const MidiControllerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NUX NGS6 LOOPER',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
    ),
    home: const MidiControllerPage(),
  );
}

class MidiControllerPage extends StatefulWidget {
  const MidiControllerPage({super.key});
  @override
  State<MidiControllerPage> createState() => _MidiControllerPageState();
}

class _MidiControllerPageState extends State<MidiControllerPage> {
  final MidiService _midiService = MidiService();
  List<MidiDevice> devices = [];
  int? selectedDeviceId;
  String? selectedDeviceName; // 新增：用于显示选中的设备名称
  bool drumOn = false;
  int drumStyle = 42;
  String looperStatus = '就绪';
  double looperProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDevices(); // 首次加载设备
    _midiService.setDeviceListListener((d) {
      setState(() {
        devices = d;
        debugPrint('Device list updated via listener: ${devices.length}');
        for (var device in devices) {
          debugPrint('Updated Device: ${device.deviceName}, ID: ${device.deviceId}, HasPermission: ${device.hasPermission}');
        }
        _autoSelectDevice(); // 设备列表更新时也尝试自动选择
      });
    });
  }

  Future<void> _loadDevices() async {
    try {
      // 首次加载时，先获取设备列表，此时可能尚未获得权限
      final initialDevices = await _midiService.getUsbDevices();
      debugPrint('Initial loaded devices: ${initialDevices.length}');
      for (var d in initialDevices) {
        debugPrint('Initial Device: ${d.deviceName}, ID: ${d.deviceId}, HasPermission: ${d.hasPermission}');
      }
      setState(() {
        devices = initialDevices;
        _autoSelectDevice(); // 尝试自动选择设备
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  // 提取自动选择设备的逻辑
  void _autoSelectDevice() {
    if (selectedDeviceId == null && devices.isNotEmpty) {
      final firstPermittedDevice = devices.firstWhere(
        (device) => device.hasPermission,
        orElse: () => devices.first,
      );
      selectedDeviceId = firstPermittedDevice.deviceId;
      selectedDeviceName = firstPermittedDevice.deviceName;
      debugPrint('Auto-selected device: ${selectedDeviceName} (ID: ${selectedDeviceId})');
    }
  }

  Future<void> _sendMidi(String msg) async {
    if (selectedDeviceId == null) {
      // 如果没有选择设备，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择MIDI设备')),
      );
      return;
    }
    try {
      await _midiService.sendMidiMessage(selectedDeviceId!, msg);
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送MIDI消息失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.containerBg, AppColors.background],
          ),
        ),
        child: Column(
          children: [
            MidiStatusWidget(
              selectedDeviceName: selectedDeviceName,
              devices: devices,
              midiService: _midiService,
              onDeviceSelected: (device) {
                setState(() {
                  selectedDeviceId = device.deviceId;
                  selectedDeviceName = device.deviceName;
                });
              },
              onRefreshDevices: _loadDevices,
            ),
            Expanded(
              child: MainContent(
                drumOn: drumOn,
                drumStyle: drumStyle,
                looperStatus: looperStatus,
                looperProgress: looperProgress,
                onDrumToggle: (v) {
                  setState(() => drumOn = v);
                  _sendMidi(v ? 'B0 29 01' : 'B0 29 00');
                },
                onDrumStyleChange: (v) {
                  setState(() => drumStyle = v);
                  _sendMidi('B0 2A ${v.toRadixString(16).padLeft(2, '0')}');
                },
                onClear: () {
                  setState(() {
                    looperStatus = '已清除循环';
                    looperProgress = 0.0;
                  });
                  _sendMidi('90 3E 7F');
                },
                onUndo: () {
                  setState(() {
                    looperStatus = '撤销操作';
                    looperProgress = 0.5;
                  });
                  _sendMidi('90 3F 7F');
                },
                onRec: () {
                  setState(() {
                    looperStatus = '录音中: 录制第2层';
                    looperProgress = 0.35;
                  });
                  _sendMidi('90 40 7F');
                },
                onStop: () {
                  setState(() {
                    looperStatus = '播放中: 1层录制完成';
                    looperProgress = 0.65;
                  });
                  _sendMidi('90 41 7F');
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
