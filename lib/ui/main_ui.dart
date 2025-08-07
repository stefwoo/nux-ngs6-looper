import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/bloc/app_cubit.dart';
import 'package:midi_controller/services/permission_handler.dart';

class MainUI extends StatefulWidget {
  final PermissionHandlerService permissionHandler;
  const MainUI({super.key, required this.permissionHandler});

  @override
  State<MainUI> createState() => _MainUIState();
}

class _MainUIState extends State<MainUI> {
  @override
  void initState() {
    super.initState();
    widget.permissionHandler.requestPermissions();
  }

  void _showDeviceSelectionDialog() async {
    final devices = await widget.permissionHandler.listMidiDevices();
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select MIDI Device'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text("ID: ${device.id}"),
                  onTap: () {
                    widget.permissionHandler.connectToDevice(device);
                    context.read<AppCubit>().connectToDevice(device);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('NUX NGS6 LOOPER'),
        backgroundColor: Colors.grey[850],
        actions: [
          TextButton(
            onPressed: _showDeviceSelectionDialog,
            child: const Text('Select Device'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DrumControlWidget(),
            const SizedBox(height: 20),
            const StyleControlWidget(),
            const SizedBox(height: 20),
            const LooperSection(),
            const Spacer(),
            const Center(
              child: Text(
                'Connect to guitar effects processor via USB MIDI',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrumControlWidget extends StatelessWidget {
  const DrumControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Drum', style: TextStyle(fontSize: 18)),
            BlocBuilder<AppCubit, AppState>(
              builder: (context, state) {
                return Switch(
                  value: state.drumOn,
                  onChanged: (_) => context.read<AppCubit>().toggleDrum(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class StyleControlWidget extends StatelessWidget {
  const StyleControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Style (0-42)', style: TextStyle(fontSize: 18)),
            BlocBuilder<AppCubit, AppState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: state.drumStyle.toDouble(),
                            min: 0,
                            max: 42,
                            divisions: 42,
                            onChanged: (value) => context.read<AppCubit>().changeDrumStyle(value.toInt()),
                          ),
                        ),
                        Text(
                          state.drumStyle.toRadixString(16).toUpperCase().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            final currentStyle = state.drumStyle;
                            if (currentStyle > 0) {
                              context.read<AppCubit>().changeDrumStyle(currentStyle - 1);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final currentStyle = state.drumStyle;
                            if (currentStyle < 42) {
                              context.read<AppCubit>().changeDrumStyle(currentStyle + 1);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LooperSection extends StatelessWidget {
  const LooperSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LOOPER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const LooperStatusWidget(),
        const SizedBox(height: 20),
        const LooperControlsWidget(),
      ],
    );
  }
}

class LooperStatusWidget extends StatelessWidget {
  const LooperStatusWidget({super.key});

  String _getStatusText(AppState state) {
    switch (state.recButtonState) {
      case RecButtonState.rec:
        return 'Ready';
      case RecButtonState.waitRec:
        return 'Wait Rec';
      case RecButtonState.recording:
        return 'Recording Layer 1';
      case RecButtonState.playing:
      case RecButtonState.duoRecComplete:
        return 'Playing Layer ${state.layerCount}';
      case RecButtonState.duoRec:
        // 使用 layerCout 显示正在叠加的层数
        return 'Dubbing Layer ${state.layerCount}';
      case RecButtonState.play:
        return 'Stopped';
      default:
        return 'Unknown';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitMilliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0').substring(0, 2);
    return "$twoDigitMinutes:$twoDigitSeconds.$twoDigitMilliseconds";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: BlocBuilder<AppCubit, AppState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Current Status', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      _getStatusText(state),
                      key: ValueKey<String>(_getStatusText(state)), // Important for AnimatedSwitcher
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlueAccent),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LooperControlsWidget extends StatelessWidget {
  const LooperControlsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _LooperButton(
          label: 'CLEAR',
          icon: Icons.close,
          onPressed: () => context.read<AppCubit>().pressClear(),
          color: Colors.purple,
        ),
        // 将Undo按钮包裹在BlocBuilder中以动态更新
        BlocBuilder<AppCubit, AppState>(
          builder: (context, state) {
            final isRedo = state.undoButtonState == UndoButtonState.redo;
            final canUndo = state.undoButtonState != UndoButtonState.none;

            return _LooperButton(
              // 动态改变Label
              label: isRedo ? 'REDO' : 'UNDO',
              icon: isRedo ? Icons.redo : Icons.undo,
              // 只有在可Undo/Redo时才响应点击
              onPressed: canUndo ? () => context.read<AppCubit>().pressUndo() : () {},
              // 当按钮不可用时，可以改变颜色以提示用户
              color: canUndo ? Colors.blue : Colors.grey,
            );
          },
        ),
        _LooperButton(
          label: 'REC',
          icon: Icons.circle,
          onPressed: () => context.read<AppCubit>().pressRec(),
          color: Colors.red,
        ),
        _LooperButton(
          label: 'STOP',
          icon: Icons.stop,
          onPressed: () => context.read<AppCubit>().pressStop(),
          color: Colors.brown,
        ),
      ],
    );
  }
}

class _LooperButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _LooperButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
