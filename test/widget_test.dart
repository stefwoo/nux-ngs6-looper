// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midi_controller/main.dart';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/services/permission_handler.dart';

void main() {
  testWidgets('App starts up smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final midiCommand = MidiCommand();
    final permissionHandler = PermissionHandlerService(midiCommand);
    await tester.pumpWidget(MyApp(permissionHandler: permissionHandler));

    // Verify that the app title is shown.
    expect(find.text('NUX NGS6 LOOPER'), findsOneWidget);
  });
}
