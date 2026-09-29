import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdserver/features/focus_guard/models/focus_config_model.dart';
import 'package:fdserver/features/focus_guard/providers/focus_guard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FocusConfigModel & Quotes Tests', () {
    test('BlockedAppInfo serialization', () {
      const app = BlockedAppInfo(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isBlocked: true,
        isShortsOnly: false,
      );

      final json = app.toJson();
      expect(json['packageName'], 'com.instagram.android');
      expect(json['isBlocked'], true);

      final reconstructed = BlockedAppInfo.fromJson(json);
      expect(reconstructed.packageName, app.packageName);
      expect(reconstructed.appName, app.appName);
      expect(reconstructed.isBlocked, true);
    });

    test('Reality Quotes availability', () {
      expect(RealityQuote.curatedQuotes.isNotEmpty, true);
      for (final quote in RealityQuote.curatedQuotes) {
        expect(quote.quote.isNotEmpty, true);
        expect(quote.author.isNotEmpty, true);
      }
    });
  });

  group('FocusGuardProvider Anti-Bypass & Logic Tests', () {
    test('Initial state and defaults', () {
      final provider = FocusGuardProvider();
      expect(provider.isLockActive, false);
      expect(provider.blockShortsAndReels, true);
      expect(provider.blockedApps.isNotEmpty, true);
      expect(provider.targetGoal.isNotEmpty, true);
      expect(provider.sessionDurationMinutes, 25);
    });

    test('Goal updating', () async {
      final provider = FocusGuardProvider();
      await provider.setGoal('Build an autonomous AI SaaS');
      expect(provider.targetGoal, 'Build an autonomous AI SaaS');
    });

    test('Toggle app blocking status', () {
      final provider = FocusGuardProvider();
      final initialCount = provider.blockedApps.length;

      provider.toggleAppBlocked('com.instagram.android');
      final insta = provider.blockedApps.firstWhere((a) => a.packageName == 'com.instagram.android');
      expect(insta.isBlocked, false); // Toggled from default true to false

      provider.toggleAppBlocked('com.instagram.android');
      final instaAfter = provider.blockedApps.firstWhere((a) => a.packageName == 'com.instagram.android');
      expect(instaAfter.isBlocked, true); // Toggled back
      expect(provider.blockedApps.length, initialCount);
    });

    test('Hardcore Math Challenge verification', () {
      final provider = FocusGuardProvider();
      final expected = provider.expectedMathResult;
      expect(expected > 0, true);

      // Wrong answer should fail and regenerate
      final wrongUnlock = provider.verifyAndEmergencyUnlockWithMath(expected + 999);
      expect(wrongUnlock, false);

      // Correct answer should pass
      final rightUnlock = provider.verifyAndEmergencyUnlockWithMath(provider.expectedMathResult);
      expect(rightUnlock, true);
    });

    test('Hardcore Accountability Oath verification', () {
      final provider = FocusGuardProvider();
      expect(
        provider.verifyAndEmergencyUnlockWithOath('I am choosing short-term dopamine over my future and I accept the cost.'),
        true,
      );
      expect(
        provider.verifyAndEmergencyUnlockWithOath('I want to watch YouTube please'),
        false,
      );
    });

    test('Hourly Budget and Auto-Diversion configuration', () async {
      final provider = FocusGuardProvider();
      // Default: 5 minutes hourly budget, auto divert enabled, diversion type 'pdf'
      expect(provider.hourlyBudgetMinutes, 5);
      expect(provider.autoDivertEnabled, true);
      expect(provider.diversionType, 'pdf');

      // Update hourly budget to 10m
      await provider.setHourlyBudgetMinutes(10);
      expect(provider.hourlyBudgetMinutes, 10);

      // Update hourly budget to strict (0m)
      await provider.setHourlyBudgetMinutes(0);
      expect(provider.hourlyBudgetMinutes, 0);

      // Update diversion type to video
      await provider.setDiversionType('video');
      expect(provider.diversionType, 'video');

      // Update diversion type to reality_screen
      await provider.setDiversionType('reality_screen');
      expect(provider.diversionType, 'reality_screen');

      // Toggle auto divert
      await provider.setAutoDivertEnabled(false);
      expect(provider.autoDivertEnabled, false);
    });
  });
}
