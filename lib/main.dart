import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/bloc/app_cubit.dart';
import 'package:midi_controller/services/midi_engine.dart';
import 'package:midi_controller/services/permission_handler.dart';
import 'package:midi_controller/ui/main_ui.dart';

void main() {
  // Create the singletons
  final midiCommand = MidiCommand();
  final midiEngine = MidiEngine(midiCommand);
  final permissionHandler = PermissionHandlerService(midiCommand);

  runApp(
    BlocProvider(
      create: (context) => AppCubit(midiEngine),
      child: MyApp(permissionHandler: permissionHandler),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PermissionHandlerService permissionHandler;
  const MyApp({super.key, required this.permissionHandler});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIDI Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[800],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: MainUI(permissionHandler: permissionHandler),
    );
  }
}
