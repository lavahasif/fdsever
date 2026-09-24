import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdserver/core/services/power_service.dart';
import 'package:fdserver/core/services/storage_service.dart';
import 'package:fdserver/features/settings/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PowerService Tests', () {
    late PowerService powerService;

    setUp(() {
      powerService = PowerService();
    });

    tearDown(() {
      powerService.dispose();
    });

    test('Initializes safely and reports default states', () async {
      await powerService.init();
      expect(powerService.isWakeLockHeld, isFalse);
      expect(powerService.isScreenKeepOn, isFalse);
    });

    test('Manages active consumer wake locks via Set reference counting', () async {
      expect(powerService.isWakeLockHeld, isFalse);

      await powerService.acquireWakeLock('apk_download');
      expect(powerService.isWakeLockHeld, isTrue);
      expect(powerService.activeConsumers.contains('apk_download'), isTrue);

      await powerService.acquireWakeLock('proxy_server');
      expect(powerService.isWakeLockHeld, isTrue);
      expect(powerService.activeConsumers.length, equals(2));

      await powerService.releaseWakeLock('apk_download');
      expect(powerService.isWakeLockHeld, isTrue);
      expect(powerService.activeConsumers.contains('apk_download'), isFalse);
      expect(powerService.activeConsumers.contains('proxy_server'), isTrue);

      await powerService.releaseWakeLock('proxy_server');
      expect(powerService.isWakeLockHeld, isFalse);
      expect(powerService.activeConsumers.isEmpty, isTrue);
    });

    test('Honors forced user CPU wake lock independent of consumers', () async {
      await powerService.setForcedCpuAwake(true);
      expect(powerService.isWakeLockHeld, isTrue);
      expect(powerService.isForcedCpuAwake, isTrue);

      await powerService.setForcedCpuAwake(false);
      expect(powerService.isWakeLockHeld, isFalse);
      expect(powerService.isForcedCpuAwake, isFalse);
    });

    test('Toggles keep screen on state', () async {
      await powerService.setKeepScreenOn(true);
      expect(powerService.isScreenKeepOn, isTrue);

      await powerService.setKeepScreenOn(false);
      expect(powerService.isScreenKeepOn, isFalse);
    });
  });

  group('SettingsProvider Power & Battery Integration', () {
    late StorageService storageService;
    late PowerService powerService;
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = await StorageService.init();
      powerService = PowerService();
      settingsProvider = SettingsProvider(storageService, powerService);
    });

    tearDown(() {
      settingsProvider.dispose();
      powerService.dispose();
    });

    test('Loads and toggles keep screen on preference', () async {
      expect(settingsProvider.keepScreenOn, isFalse);

      await settingsProvider.toggleKeepScreenOn(true);
      expect(settingsProvider.keepScreenOn, isTrue);
      expect(storageService.getKeepScreenOn(), isTrue);

      await settingsProvider.toggleKeepScreenOn(false);
      expect(settingsProvider.keepScreenOn, isFalse);
      expect(storageService.getKeepScreenOn(), isFalse);
    });

    test('Loads and toggles keep CPU awake preference', () async {
      expect(settingsProvider.keepCpuAwake, isFalse);

      await settingsProvider.toggleKeepCpuAwake(true);
      expect(settingsProvider.keepCpuAwake, isTrue);
      expect(powerService.isWakeLockHeld, isTrue);
      expect(storageService.getKeepCpuAwake(), isTrue);

      await settingsProvider.toggleKeepCpuAwake(false);
      expect(settingsProvider.keepCpuAwake, isFalse);
      expect(powerService.isWakeLockHeld, isFalse);
      expect(storageService.getKeepCpuAwake(), isFalse);
    });
  });
}
