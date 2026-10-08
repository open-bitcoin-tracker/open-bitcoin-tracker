import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/app/app_providers.dart';
import 'package:open_bitcoin_tracker/data/data.dart';
import 'package:open_bitcoin_tracker/services/stacks_crypto_service.dart';
import 'package:open_bitcoin_tracker/services/stacks_unlock_orchestrator.dart';
import 'package:open_bitcoin_tracker/state/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('parent rebuilds retain one coherent dependency graph', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final samples = <List<Object>>[];
    Widget host() => AppProviders(
      prefs: prefs,
      child: Builder(
        builder: (context) {
          samples.add([
            context.read<StacksCryptoService>(),
            context.read<AppStateRepository>(),
            context.read<AppStateNotifier>(),
            context.read<StacksUnlockOrchestrator>(),
            context.read<ConverterState>(),
          ]);
          return const SizedBox.shrink();
        },
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpWidget(host());
    for (var i = 0; i < samples.first.length; i++) {
      expect(identical(samples.first[i], samples.last[i]), isTrue);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
