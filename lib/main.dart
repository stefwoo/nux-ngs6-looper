import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'models/midi_device.dart';
import 'services/midi_service.dart';
import 'widgets/drum_controls.dart';
import 'widgets/looper_status.dart';
import 'widgets/looper_controls.dart';

void main() => runApp(const MidiControllerApp());

class MidiControllerApp extends StatelessWidget {
  const MidiControllerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NUX NGS6 LOOPER',
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AppColors.background),
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
  bool drumOn = false;
  int drumStyle = 42;
  String looperStatus = '就绪';
  double looperProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _midiService.setDeviceListListener((d) => setState(() => devices = d));
  }

  Future<void> _loadDevices() async {
    try {
      devices = await _midiService.getUsbDevices();
      setState(() {});
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _sendMidi(String msg) async {
    if (selectedDeviceId == null) return;
    try {
      await _midiService.sendMidiMessage(selectedDeviceId!, msg);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showDeviceDialog() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('选择MIDI设备'),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(devices[i].deviceName),
                subtitle: Text('VID: ${devices[i].vendorId} PID: ${devices[i].productId}'),
                onTap: () {
                  setState(() => selectedDeviceId = devices[i].deviceId);
                  Navigator.pop(context); // 添加这行来关闭对话框
                },
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.containerBg, AppColors.background]),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.topCenter, // 调整为顶部居中对齐
                    children: [
                      Positioned(
                        top: 0, // 放置在顶部
                        right: 0, // 放置在右侧
                        child: GestureDetector(
                          onTap: _showDeviceDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              selectedDeviceId != null ? 'MIDI已连接' : '选择设备',
                              style: const TextStyle(fontSize: 12, color: AppColors.accentGreen),
                            ),
                          ),
                        ),
                      ),
                      const Padding( // 给标题添加顶部填充，避免与MIDI状态重叠
                        padding: EdgeInsets.only(top: 20.0), // 调整此值以获得最佳视觉效果
                        child: Text('NUX NGS6 LOOPER',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DrumControls(
                    isOn: drumOn,
                    styleValue: drumStyle,
                    onToggle: (v) {
                      setState(() => drumOn = v);
                      _sendMidi(v ? '90 3C 7F' : '80 3C 7F');
                    },
                    onStyleChange: (v) {
                      setState(() => drumStyle = v);
                      _sendMidi('90 3D ${v.toRadixString(16)}');
                    },
                  ),
                  const SizedBox(height: 20),
                  LooperStatus(status: looperStatus, progress: looperProgress),
                  const SizedBox(height: 20),
                  LooperControls(
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
                  const SizedBox(height: 20),
                  const Text(
                    '通过USB MIDI控制连接至吉他效果器',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
