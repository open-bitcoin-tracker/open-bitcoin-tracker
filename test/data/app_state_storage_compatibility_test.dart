import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/data/app_state.dart';

// Captured with the original AppState encoder before the state refactor.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/app_state_$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('fresh-install defaults keep the original storage contract', () {
    expect(const AppState().toJson(), _fixture('default'));
    // Legacy empty JSON uses the enum's 1m lock fallback; a fresh AppState
    // constructor uses 5m. Preserve both existing paths.
    expect(AppState.fromJson({}).toJson(), _fixture('empty_json'));
  });

  test('all saved preferences and stack fields round-trip unchanged', () {
    final original = _fixture('populated');
    final restored = AppState.fromJson(original);
    expect(restored.toJson(), original);
    expect(restored.copyWith(showChart: true).stacks, same(restored.stacks));
  });

  test('encrypted settings encoding omits only the plaintext stack list', () {
    final original = _fixture('populated');
    final state = AppState.fromJson(original);
    final settings = state.toJson(includeStacks: false);
    expect(settings.containsKey('stacks'), isFalse);
    expect(settings, {...original}..remove('stacks'));
    expect(state.toJson(), original);
  });
}
