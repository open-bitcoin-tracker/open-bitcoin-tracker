import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/data/app_enums.dart';
import 'package:open_bitcoin_tracker/screens/converter/converter_screen.dart';
import 'package:open_bitcoin_tracker/screens/edit_stack_screens.dart';
import 'package:open_bitcoin_tracker/screens/full_screen_price/full_screen_price_screen.dart';
import 'package:open_bitcoin_tracker/screens/home/home_screen.dart';
import 'package:open_bitcoin_tracker/screens/new_stack_screens.dart';
import 'package:open_bitcoin_tracker/screens/stack_detail/stack_detail_screen.dart';
import 'package:open_bitcoin_tracker/state/app_state_notifier.dart';

import '../support/app_test_host.dart';
import '../support/test_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
  });
  const portfolio =
      '{"stacks":[{"id":"s1","name":"Cold wallet","sats":123456789},{"id":"s2","name":"Savings","sats":50000000}],"showPortfolio":true}';
  final cases = <String, (Widget, String, Size)>{
    'home_empty': (HomeScreen(onAddStack: () {}), '{}', const Size(400, 850)),
    'home_portfolio': (
      HomeScreen(onAddStack: () {}),
      portfolio,
      const Size(400, 850),
    ),
    'home_landscape': (
      HomeScreen(onAddStack: () {}),
      portfolio,
      const Size(850, 400),
    ),
    'converter_btc': (
      const ConverterScreen(),
      '{"converterFiatModeRaw":"5"}',
      const Size(400, 850),
    ),
    'converter_sats': (
      const ConverterScreen(),
      '{"converterMode":"sats","converterSatsModeRaw":"100000000"}',
      const Size(400, 850),
    ),
    'new_stack': (
      const NewStackAmountScreen(initialSats: 123456789),
      '{}',
      const Size(400, 850),
    ),
    'edit_stack': (
      const EditStackAmountScreen(stackId: 's1'),
      portfolio,
      const Size(400, 850),
    ),
    'stack_detail': (
      const StackDetailScreen(stackId: 's1'),
      portfolio,
      const Size(400, 850),
    ),
    'full_screen_price': (
      const FullScreenPriceScreen(currency: Currency.usd),
      '{}',
      const Size(850, 400),
    ),
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key} keeps its visual appearance', (tester) async {
      final (screen, state, size) = entry.value;
      setTestViewport(tester, size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('visual-root'),
          child: await appTestHost(screen, initialState: state),
        ),
      );
      await tester.pump();
      await tester.pump(AppStateNotifier.saveDebounceWindow);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('visual-root')),
        matchesGoldenFile('../goldens/${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
