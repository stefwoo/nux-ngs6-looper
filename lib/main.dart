import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MidiControllerApp());
}

class MidiControllerApp extends StatelessWidget {
  const MidiControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIDI Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MidiControllerPage(),
    );
  }
}

class MidiControllerPage extends StatefulWidget {
  const MidiControllerPage({super.key});

  @override
  State<MidiControllerPage> createState() => _MidiControllerPageState();
}

class _MidiControllerPageState extends State<MidiControllerPage> {
  static const platform = MethodChannel('com.example.midi_controller/usb');
  List<Map<String, dynamic>> devices = [];
  int? selectedDeviceId;
  List<ButtonState> buttonStates = List.generate(4, (_) => ButtonState.idle);
  List<bool> buttonToggleStates = List.generate(4, (_) => false); // ON/OFF状态
  List<Map<String, dynamic>> buttonConfigs = [
    {
      'name': '按钮1', 
      'onMessage': '90 3C 7F',   // 按下时发送的MIDI消息 (Note On)
      'offMessage': '80 3C 7F',  // 释放时发送的MIDI消息 (Note Off)
      'color': Colors.blue.value
    },
    {
      'name': '按钮2', 
      'onMessage': '90 3D 7F', 
      'offMessage': '80 3D 7F', 
      'color': Colors.blue.value
    },
    {
      'name': '按钮3', 
      'onMessage': '90 3E 7F', 
      'offMessage': '80 3E 7F', 
      'color': Colors.blue.value
    },
    {
      'name': '按钮4', 
      'onMessage': '90 3F 7F', 
      'offMessage': '80 3F 7F', 
      'color': Colors.blue.value
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsbDevices();
    _setupDeviceListListener();
  }

  void _setupDeviceListListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceListUpdated') {
        final result = call.arguments as List;
        setState(() {
          devices = result.map((item) {
            final map = Map<String, dynamic>.from(item);
            return {
              'deviceId': map['deviceId'] as int,
              'deviceName': map['deviceName'] as String? ?? '未知设备',
              'vendorId': map['vendorId'] as int,
              'productId': map['productId'] as int,
              'hasPermission': map['hasPermission'] as bool? ?? false,
            };
          }).toList();
        });
        debugPrint("Device list updated: ${devices.length} devices found");
      }
    });
  }

  Future<void> _loadUsbDevices() async {
    try {
      final result = await platform.invokeMethod('getUsbDevices');
      setState(() {
        devices = (result as List).map((item) {
          final map = Map<String, dynamic>.from(item);
          return {
            'deviceId': map['deviceId'] as int,
            'deviceName': map['deviceName'] as String? ?? '未知设备',
            'vendorId': map['vendorId'] as int,
            'productId': map['productId'] as int,
            'hasPermission': map['hasPermission'] as bool? ?? false,
          };
        }).toList();
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get USB devices: '${e.message}'.");
    }
  }

  Future<void> _sendMidiMessage(int buttonIndex) async {
    if (selectedDeviceId == null) {
      _showError('请先选择MIDI设备');
      return;
    }

    setState(() {
      buttonStates[buttonIndex] = ButtonState.sending;
    });

    try {
      // 切换按钮状态
      final isCurrentlyOn = buttonToggleStates[buttonIndex];
      final messageToSend = isCurrentlyOn 
          ? buttonConfigs[buttonIndex]['offMessage']  // 当前是ON，发送OFF消息
          : buttonConfigs[buttonIndex]['onMessage'];  // 当前是OFF，发送ON消息

      final success = await platform.invokeMethod('sendMidiMessage', {
        'deviceId': selectedDeviceId,
        'message': messageToSend,
      });

      if (success) {
        setState(() {
          buttonToggleStates[buttonIndex] = !isCurrentlyOn; // 切换状态
          buttonStates[buttonIndex] = ButtonState.sent;
        });
        debugPrint('Button $buttonIndex toggled to ${buttonToggleStates[buttonIndex] ? "ON" : "OFF"}');
      } else {
        setState(() {
          buttonStates[buttonIndex] = ButtonState.error;
        });
        _showError('发送MIDI消息失败');
      }
    } on PlatformException catch (e) {
      setState(() {
        buttonStates[buttonIndex] = ButtonState.error;
      });
      _showError('发送MIDI消息时出错: ${e.message}');
    }

    // 重置按钮发送状态
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          buttonStates[buttonIndex] = ButtonState.idle;
        });
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDI控制器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<int>(
              value: selectedDeviceId,
              hint: const Text('选择MIDI设备'),
              items: devices.map((device) {
                return DropdownMenuItem<int>(
                  value: device['deviceId'],
                  child: Text(device['deviceName'] ?? '未知设备'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDeviceId = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: List.generate(4, (index) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(buttonStates[index], buttonToggleStates[index]),
                      side: buttonToggleStates[index] 
                          ? const BorderSide(color: Colors.white, width: 3) 
                          : null,
                    ),
                    onPressed: () => _sendMidiMessage(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonConfigs[index]['name'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          buttonToggleStates[index] ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 14,
                            color: buttonToggleStates[index] ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showConfigDialog,
        child: const Icon(Icons.settings),
      ),
    );
  }

  Future<void> _showConfigDialog() async {
    final newConfigs = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => ConfigDialog(buttonConfigs: buttonConfigs),
    );
    if (newConfigs != null) {
      setState(() {
        buttonConfigs = newConfigs;
      });
    }
  }

  Color _getButtonColor(ButtonState state, bool isToggleOn) {
    switch (state) {
      case ButtonState.idle:
        return isToggleOn ? Colors.green : Colors.blue;
      case ButtonState.sending:
        return Colors.orange;
      case ButtonState.sent:
        return isToggleOn ? Colors.green : Colors.blue;
      case ButtonState.error:
        return Colors.red;
    }
  }
}

class ConfigDialog extends StatefulWidget {
  final List<Map<String, dynamic>> buttonConfigs;

  const ConfigDialog({super.key, required this.buttonConfigs});

  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  late List<Map<String, dynamic>> tempConfigs;

  @override
  void initState() {
    super.initState();
    tempConfigs = List.from(widget.buttonConfigs);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('按钮配置'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: tempConfigs.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '按钮 ${index + 1}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(labelText: '按钮名称', isDense: true),
                      controller: TextEditingController(text: tempConfigs[index]['name']),
                      onChanged: (value) => tempConfigs[index]['name'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(labelText: 'ON消息 (按下)', isDense: true),
                      controller: TextEditingController(text: tempConfigs[index]['onMessage']),
                      onChanged: (value) => tempConfigs[index]['onMessage'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(labelText: 'OFF消息 (释放)', isDense: true),
                      controller: TextEditingController(text: tempConfigs[index]['offMessage']),
                      onChanged: (value) => tempConfigs[index]['offMessage'] = value,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, tempConfigs),
          child: const Text('保存'),
        ),
      ],
    );
  }

  Color _getButtonColor(ButtonState state) {
    switch (state) {
      case ButtonState.idle:
        return Colors.blue;
      case ButtonState.sending:
        return Colors.orange;
      case ButtonState.sent:
        return Colors.green;
      case ButtonState.error:
        return Colors.red;
    }
  }
}

enum ButtonState {
  idle,
  sending,
  sent,
  error,
}
