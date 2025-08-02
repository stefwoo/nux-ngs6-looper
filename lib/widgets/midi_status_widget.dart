import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/midi_device.dart';
import '../services/midi_service.dart';

class MidiStatusWidget extends StatefulWidget {
  final String? selectedDeviceName;
  final List<MidiDevice> devices;
  final MidiService midiService;
  final ValueChanged<MidiDevice> onDeviceSelected;
  final VoidCallback? onRefreshDevices;

  const MidiStatusWidget({
    super.key,
    required this.selectedDeviceName,
    required this.devices,
    required this.midiService,
    required this.onDeviceSelected,
    this.onRefreshDevices,
  });

  @override
  State<MidiStatusWidget> createState() => _MidiStatusWidgetState();
}

class _MidiStatusWidgetState extends State<MidiStatusWidget> {
  Set<int> _requestingPermission = <int>{};

  Future<void> _requestPermission(MidiDevice device) async {
    if (_requestingPermission.contains(device.deviceId)) return;
    
    setState(() {
      _requestingPermission.add(device.deviceId);
    });

    try {
      await widget.midiService.requestUsbPermission(device.deviceId);
      // 权限请求成功后，设备列表会通过监听器自动更新
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已请求权限: ${device.deviceName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('权限请求失败: $e')),
      );
    } finally {
      setState(() {
        _requestingPermission.remove(device.deviceId);
      });
    }
  }

  void _showDeviceDialog() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选择MIDI设备'),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.onRefreshDevices,
                tooltip: '刷新设备列表',
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: widget.devices.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('没有可用的MIDI设备。'),
                      const SizedBox(height: 8),
                      const Text('请连接USB MIDI设备后点击刷新。', 
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.devices.length,
                    itemBuilder: (c, i) {
                      final device = widget.devices[i];
                      final isRequesting = _requestingPermission.contains(device.deviceId);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(device.deviceName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VID: ${device.vendorId.toRadixString(16).toUpperCase()} PID: ${device.productId.toRadixString(16).toUpperCase()}'),
                              Row(
                                children: [
                                  Icon(
                                    device.hasPermission ? Icons.check_circle : Icons.warning,
                                    size: 16,
                                    color: device.hasPermission ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    device.hasPermission ? '权限已授予' : '需要权限',
                                    style: TextStyle(
                                      color: device.hasPermission ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: device.hasPermission
                              ? const Icon(Icons.arrow_forward_ios, size: 16)
                              : isRequesting
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _requestPermission(device),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accentGreen,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(60, 30),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('授权', style: TextStyle(fontSize: 12)),
                                    ),
                          onTap: device.hasPermission
                              ? () {
                                  widget.onDeviceSelected(device);
                                  Navigator.pop(context);
                                }
                              : null,
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
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: _showDeviceDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.selectedDeviceName != null ? 'MIDI: ${widget.selectedDeviceName}' : '选择设备',
                style: const TextStyle(fontSize: 12, color: AppColors.accentGreen),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text('NUX NGS6 LOOPER',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300)),
        ),
      ],
    );
  }
}
