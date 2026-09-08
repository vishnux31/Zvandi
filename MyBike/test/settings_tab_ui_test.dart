import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/settings/settings_tab.dart';

void main() {
  testWidgets('SettingsTab renders preferences, switches, and sign-out button', (WidgetTester tester) async {
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

    // Verify visual headers exist. The "ADMINISTRATIVE" section (Export
    // Diagnostic Telemetry / Encryption & Keys) was removed in UAT Phase 1:
    // both rows only ever showed a snackbar and did nothing real.
    expect(find.text('COCKPIT PREFERENCES'), findsOneWidget);
    expect(find.text('VEHICLE NOTIFICATIONS'), findsOneWidget);
    expect(find.text('ADMINISTRATIVE'), findsNothing);

    // Verify distance speed units toggle text
    expect(find.text('Distance & Speed Unit'), findsOneWidget);
    expect(find.text('Temperature Unit'), findsOneWidget);

    // Verify notifications toggle row titles are visible. "Security &
    // Movement" was removed in UAT Phase 5 — no GPS/telemetry hardware
    // feature backs it.
    expect(find.text('Critical Alerts'), findsOneWidget);
    expect(find.text('Maintenance Reminders'), findsOneWidget);
    expect(find.text('Security & Movement'), findsNothing);

    // Verify switch elements exist by testTag keys
    final criticalSwitch = find.byKey(const ValueKey('toggle_critical_alerts'));
    final maintenanceSwitch = find.byKey(const ValueKey('toggle_maintenance_reminders'));

    expect(criticalSwitch, findsOneWidget);
    expect(maintenanceSwitch, findsOneWidget);
    expect(find.byKey(const ValueKey('toggle_security_&_movement')), findsNothing);

    // Verify the (now-removed) fake administrative actions are gone.
    expect(find.text('Export Diagnostic Telemetry'), findsNothing);
    expect(find.text('Encryption & Keys'), findsNothing);

    // Verify sign out button is present by key
    expect(find.byKey(const ValueKey('sign_out_button')), findsOneWidget);
  });
}
