import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/settings/settings_tab.dart';

void main() {
  testWidgets('SettingsTab renders preferences, switches, administrative items, and sign-out button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsTab(),
          ),
        ),
      ),
    );

    // Verify visual headers exist
    expect(find.text('COCKPIT PREFERENCES'), findsOneWidget);
    expect(find.text('VEHICLE NOTIFICATIONS'), findsOneWidget);
    expect(find.text('ADMINISTRATIVE'), findsOneWidget);

    // Verify distance speed units toggle text
    expect(find.text('Distance & Speed Unit'), findsOneWidget);
    expect(find.text('Temperature Unit'), findsOneWidget);

    // Verify notifications toggle row titles are visible
    expect(find.text('Critical Alerts'), findsOneWidget);
    expect(find.text('Maintenance Reminders'), findsOneWidget);
    expect(find.text('Security & Movement'), findsOneWidget);

    // Verify switch elements exist by testTag keys
    final criticalSwitch = find.byKey(const ValueKey('toggle_critical_alerts'));
    final maintenanceSwitch = find.byKey(const ValueKey('toggle_maintenance_reminders'));
    final securitySwitch = find.byKey(const ValueKey('toggle_security_&_movement'));

    expect(criticalSwitch, findsOneWidget);
    expect(maintenanceSwitch, findsOneWidget);
    expect(securitySwitch, findsOneWidget);

    // Verify administrative list tiles are present
    expect(find.text('Export Diagnostic Telemetry'), findsOneWidget);
    expect(find.text('Encryption & Keys'), findsOneWidget);

    // Verify sign out button is present by key
    expect(find.byKey(const ValueKey('sign_out_button')), findsOneWidget);
  });
}
