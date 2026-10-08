import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/data/data.dart';

void main() {
  test('collections snapshot inputs and cannot be mutated through state', () {
    final stacks = [const Stack(id: 'a', name: 'A', sats: 1)];
    final currencies = [Currency.usd, Currency.eur];
    final order = [HomeWidget.stacks];
    final state = const AppState().copyWith(
      stacks: stacks,
      selectedCurrencies: currencies,
      homeWidgetOrder: order,
    );
    stacks.clear();
    currencies.clear();
    order.clear();
    expect(state.stacks, hasLength(1));
    expect(state.selectedCurrencies, [Currency.usd, Currency.eur]);
    expect(state.homeWidgetOrder, [HomeWidget.stacks]);
    expect(() => state.stacks.clear(), throwsUnsupportedError);
    expect(() => state.selectedCurrencies.clear(), throwsUnsupportedError);
    expect(() => state.homeWidgetOrder.clear(), throwsUnsupportedError);
  });

  test(
    'settings and converter updates preserve encryption cache identities',
    () {
      final state = const AppState().copyWith(
        stacks: [const Stack(id: 'a', name: 'A', sats: 1)],
      );
      final settings = state.copyWith(
        theme: AppTheme.dark,
        converterFiatModeRaw: '123',
      );
      expect(identical(state.portfolio, settings.portfolio), isTrue);
      expect(identical(state.stacks, settings.stacks), isTrue);
      final avatar = settings.copyWith(totalImageData: 'AAAB');
      expect(identical(state.stacks, avatar.stacks), isTrue);
      expect(identical(state.security, avatar.security), isTrue);
      expect(identical(settings.converter, avatar.converter), isTrue);
    },
  );
}
