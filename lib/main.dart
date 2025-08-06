import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/services/midi_engine.dart';
import 'package:midi_controller/services/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIDI Controller Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'MIDI Test Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MidiCommand _midiCommand = MidiCommand();
  late final PermissionHandlerService _permissionService;
  late final MidiEngine _midiEngine;
  List<MidiDevice> _devices = [];
  MidiDevice? _connectedDevice;
  String _status = 'Not Connected';
  MidiSignal? _lastReceivedSignal;
  StreamSubscription<MidiSignal>? _signalSubscription;

  @override
  void initState() {
    super.initState();
    _permissionService = PermissionHandlerService(_midiCommand);
    _midiEngine = MidiEngine(_midiCommand);
    _signalSubscription = _midiEngine.signalStream.listen((signal) {
      if (mounted) {
        setState(() {
          _lastReceivedSignal = signal;
        });
      }
    });
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    _midiEngine.dispose();
    super.dispose();
  }

  void _requestPermissions() async {
    await _permissionService.requestPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions Requested')),
      );
    }
  }

  void _scanDevices() async {
    final devices = await _permissionService.listMidiDevices();
    setState(() {
      _devices = devices;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device scan complete')),
      );
    }
  }

  void _connectToDevice(MidiDevice device) async {
    await _permissionService.connectToDevice(device);
    _midiEngine.startListening(device);
    setState(() {
      _connectedDevice = device;
      _status = 'Connected to ${device.name}';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    }
  }

  void _sendAndRelisten(int controlIndex) {
    if (_connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No device connected')),
      );
      return;
    }
    _midiEngine.sendControlSignal(controlIndex);
    // Re-establish listener as a workaround for potential stream interruption
    _midiEngine.startListening(_connectedDevice!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Request Permissions'),
                  ),
                  ElevatedButton(
                    onPressed: _scanDevices,
                    child: const Text('Scan for Devices'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Status: $_status'),
            ),
            SizedBox(
              height: 200, // Give the ListView a fixed height
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text("ID: ${device.id}, Type: ${device.type}"),
                    trailing: ElevatedButton(
                      onPressed: () => _connectToDevice(device),
                      child: const Text('Connect'),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Send MIDI Signals', style: TextStyle(fontSize: 18)),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: List.generate(8, (index) {
                return ElevatedButton(
                  onPressed: () => _sendAndRelisten(index + 1),
                  child: Text('Send ${index + 1}'),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _midiEngine.sendLastReceivedPacket,
                child: const Text('Send Last Received Packet (Echo)'),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Last Received Signal: ${_lastReceivedSignal?.toString() ?? "None"}'),
            ),
          ],
        ),
      ),
    );
  }
}
