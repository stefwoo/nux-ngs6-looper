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
  List<Map<String, dynamic>> buttonConfigs = [
    {'name': '按钮1', 'message': '90 3C 7F', 'color': Colors.blue.value},
    {'name': '按钮2', 'message': '90 3D 7F', 'color': Colors.blue.value},
    {'name': '按钮3', 'message': '90 3E 7F', 'color': Colors.blue.value},
    {'name': '按钮4', 'message': '90 3F 7F', 'color': Colors.blue.value},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsbDevices();
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
      final success = await platform.invokeMethod('sendMidiMessage', {
        'deviceId': selectedDeviceId,
        'message': buttonConfigs[buttonIndex]['message'],
      });

      setState(() {
        buttonStates[buttonIndex] = success ? ButtonState.sent : ButtonState.error;
      });

      if (!success) {
        _showError('发送MIDI消息失败');
      }
    } on PlatformException catch (e) {
      setState(() {
        buttonStates[buttonIndex] = ButtonState.error;
      });
      _showError('发送MIDI消息时出错: ${e.message}');
    }
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
                      backgroundColor: _getButtonColor(buttonStates[index]),
                    ),
                    onPressed: () => _sendMidiMessage(index),
                    child: Text(
                      buttonConfigs[index]['name'],
                      style: const TextStyle(fontSize: 20),
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
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tempConfigs.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                TextField(
                  decoration: InputDecoration(labelText: '按钮${index + 1}名称'),
                  controller: TextEditingController(text: tempConfigs[index]['name']),
                  onChanged: (value) => tempConfigs[index]['name'] = value,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'MIDI信号'),
                  controller: TextEditingController(text: tempConfigs[index]['message']),
                  onChanged: (value) => tempConfigs[index]['message'] = value,
                ),
                const SizedBox(height: 16),
              ],
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
