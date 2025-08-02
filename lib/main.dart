import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'models/midi_device.dart';
import 'models/looper_state.dart';
import 'services/midi_service.dart';
import 'services/looper_state_manager.dart';
import 'utils/midi_message_parser.dart';
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
  final LooperStateManager _looperStateManager = LooperStateManager();
  List<MidiDevice> devices = [];
  int? selectedDeviceId;
  String? selectedDeviceName;
  bool drumOn = false;
  int drumStyle = 42;
  String looperStatus = '就绪';
  double looperProgress = 0.0;
  bool _isMidiListening = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _setupMidiListeners();
    _setupLooperListeners();
  }

  void _setupMidiListeners() {
    _midiService.setDeviceListListener((d) {
      setState(() {
        devices = d;
        debugPrint('Device list updated via listener: ${devices.length}');
        for (var device in devices) {
          debugPrint('Updated Device: ${device.deviceName}, ID: ${device.deviceId}, HasPermission: ${device.hasPermission}');
        }
        _autoSelectDevice();
      });
    });

    _midiService.setMidiMessageListener((message) {
      debugPrint('Received MIDI message: $message');
      _looperStateManager.handleMidiMessage(message);
    });
  }

  void _setupLooperListeners() {
    _looperStateManager.statusStream.listen((status) {
      setState(() {
        looperStatus = status;
      });
    });

    _looperStateManager.buttonStatesStream.listen((buttonStates) {
      setState(() {
        // 触发UI重建以更新按钮状态
      });
    });
  }

  @override
  void dispose() {
    _looperStateManager.dispose();
    super.dispose();
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
      
      // 自动启动MIDI监听
      if (firstPermittedDevice.hasPermission) {
        _startMidiListening();
      }
    }
  }

  Future<void> _sendMidi(String msg) async {
    if (selectedDeviceId == null) {
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

  Future<void> _startMidiListening() async {
    if (selectedDeviceId != null && !_isMidiListening) {
      try {
        final success = await _midiService.startMidiListening(selectedDeviceId!);
        if (success) {
          setState(() {
            _isMidiListening = true;
          });
          debugPrint('MIDI listening started');
        }
      } catch (e) {
        debugPrint('Failed to start MIDI listening: $e');
      }
    }
  }

  Future<void> _stopMidiListening() async {
    if (_isMidiListening) {
      try {
        await _midiService.stopMidiListening();
        setState(() {
          _isMidiListening = false;
        });
        debugPrint('MIDI listening stopped');
      } catch (e) {
        debugPrint('Failed to stop MIDI listening: $e');
      }
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
                // 选择设备后自动开始监听
                if (device.hasPermission) {
                  _startMidiListening();
                }
              },
              onRefreshDevices: _loadDevices,
            ),
            Expanded(
              child: MainContent(
                drumOn: drumOn,
                drumStyle: drumStyle,
                looperStatus: looperStatus,
                looperProgress: looperProgress,
                buttonStates: _looperStateManager.currentButtonStates,
                onDrumToggle: (v) {
                  setState(() => drumOn = v);
                  _sendMidi(v ? 'B0 29 01' : 'B0 29 00');
                },
                onDrumStyleChange: (v) {
                  setState(() => drumStyle = v);
                  _sendMidi('B0 2A ${v.toRadixString(16).padLeft(2, '0')}');
                },
                onClear: () => _sendMidi(_looperStateManager.getClearCommand()),
                onUndo: () => _sendMidi(_looperStateManager.getUndoRedoCommand()),
                onRec: () => _sendMidi(_looperStateManager.getRecordCommand()),
                onStop: () => _sendMidi(_looperStateManager.getStopCommand()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
