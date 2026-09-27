import 'package:flutter_test/flutter_test.dart';
import 'package:fdserver/core/services/crash_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashLogService Unit Tests', () {
    late CrashLogService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = CrashLogService();
      await service.init();
      await service.clearAllLogs();
    });

    test('Initial state has no crashes', () {
      expect(service.hasCrashes, isFalse);
      expect(service.errorCount, equals(0));
      expect(service.logs, isEmpty);
    });

    test('Records breadcrumbs up to limit', () {
      service.addBreadcrumb('Navigation', 'Navigated to Proxy Server');
      service.addBreadcrumb('UserAction', 'Pressed Auto-Connect');

      expect(service.breadcrumbs.length, greaterThanOrEqualTo(2));
      final last = service.breadcrumbs.last;
      expect(last.category, equals('UserAction'));
      expect(last.message, equals('Pressed Auto-Connect'));
    });

    test('Records manual error and formats AI prompt accurately', () async {
      final testError = StateError('Target proxy connection timed out on 192.168.43.1:1080');
      final stack = StackTrace.current;

      await service.recordManualError(
        'TrafficDiverter',
        testError,
        stack,
        {'host': '192.168.43.1', 'port': 1080},
      );

      expect(service.hasCrashes, isTrue);
      expect(service.errorCount, equals(1));

      final log = service.logs.first;
      expect(log.component, equals('TrafficDiverter'));
      expect(log.message, contains('Target proxy connection timed out'));

      // Check AI prompt generation
      final aiPrompt = log.toAiPrompt();
      expect(aiPrompt, contains('### 🚨 FDServer Crash & Exception Report for AI Diagnosis'));
      expect(aiPrompt, contains('TrafficDiverter'));
      expect(aiPrompt, contains('Target proxy connection timed out'));
      expect(aiPrompt, contains('Recent Activity Breadcrumbs'));
      expect(aiPrompt, contains('Full Stack Trace'));
      expect(aiPrompt, contains('Specific Instructions for AI:'));
    });

    test('Generates comprehensive multi-event AI prompt and clears logs', () async {
      await service.recordManualError('ComponentA', 'First failure');
      await service.recordManualError('ComponentB', 'Second failure');

      expect(service.errorCount, equals(2));
      final fullPrompt = service.generateFullDiagnosticsAiPrompt();
      expect(fullPrompt, contains('Total Recorded Events'));
      expect(fullPrompt, contains('ComponentA'));
      expect(fullPrompt, contains('ComponentB'));

      await service.clearAllLogs();
      expect(service.errorCount, equals(0));
      expect(service.hasCrashes, isFalse);
    });
  });
}
