import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/data/data.dart';
import 'package:open_bitcoin_tracker/state/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'converter restores and persists both modes without mounting its screen',
    () async {
      SharedPreferences.setMockInitialValues({
        AppStateRepository.storageKey:
            '{"currency":"EUR","converterMode":"sats","converterFiatModeRaw":"5","converterSatsModeRaw":"123"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = AppStateRepository(prefs);
      final app = AppStateNotifier(repo);
      final converter = ConverterState(app: app);
      addTearDown(app.dispose);
      addTearDown(converter.dispose);
      expect(converter.raw, '123');
      converter.seedPreferences();
      expect(app.converterCurrency, Currency.eur);
      converter.edit(raw: '456');
      converter.setMode(ConverterMode.fiat);
      expect(converter.raw, '5');
      converter.edit(raw: '10');
      app.flushPendingSave();
      await repo.drainPendingSaves();
      final saved =
          jsonDecode(prefs.getString(AppStateRepository.storageKey)!)
              as Map<String, dynamic>;
      expect(saved['converterMode'], 'fiat');
      expect(saved['converterSatsModeRaw'], '456');
      expect(saved['converterFiatModeRaw'], '10');
      expect(saved['currency'], 'EUR');
    },
  );
}
