import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _header =
    'KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE\n';
String observations(String date, {bool incomplete = false}) => [
  'EXR,D,USD,EUR,SP00,A,$date,2',
  'EXR,D,GBP,EUR,SP00,A,$date,1',
  'EXR,D,AUD,EUR,SP00,A,$date,3',
  'EXR,D,CAD,EUR,SP00,A,$date,4',
  'EXR,D,CHF,EUR,SP00,A,$date,1.5',
  if (!incomplete) 'EXR,D,JPY,EUR,SP00,A,$date,300',
].join('\n');

void main() {
  late Directory dir;
  late File output;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('obt-fx-refresh-');
    output = File('${dir.path}/fx.csv');
    await output.writeAsString('original');
    final curl = File('${dir.path}/curl');
    await curl.writeAsString(
      '#!/usr/bin/env bash\nprintf \'%s\\n\' "\$ECB_TEST_RESPONSE" > "\${@: -1}"\n',
    );
    await Process.run('chmod', ['+x', curl.path]);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<ProcessResult> refresh(
    String response, {
    String start = '2026-10-17',
    String end = '2026-10-18',
  }) => Process.run(
    'bash',
    ['tools/fetch_fx_history.sh', start, end],
    environment: {
      'PATH': '${dir.path}:${Platform.environment['PATH']}',
      'FX_OUT': output.path,
      'ECB_TEST_RESPONSE': response,
      'TZ': 'Pacific/Auckland',
    },
  );

  test(
    'FX refresh seeds weekends from preceding ECB rates in any timezone',
    () async {
      final result = await refresh('$_header${observations('2026-10-16')}');
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await output.readAsLines(), [
        'date,EUR,GBP,AUD,CAD,CHF,JPY',
        '2026-10-17,0.500000,0.500000,1.500000,2.000000,0.750000,150.000000',
        '2026-10-18,0.500000,0.500000,1.500000,2.000000,0.750000,150.000000',
      ]);
    },
  );

  test('invalid ECB responses never replace the FX asset', () async {
    for (final response in [
      _header,
      'not an ECB response',
      '$_header${observations('2026-10-16', incomplete: true)}',
    ]) {
      final result = await refresh(response);
      expect(result.exitCode, isNot(0));
      expect(await output.readAsString(), 'original');
      expect(File('${output.path}.tmp').existsSync(), isFalse);
    }
  });

  test('reversed dates never replace the FX asset', () async {
    final result = await refresh(
      _header,
      start: '2026-10-18',
      end: '2026-10-17',
    );
    expect(result.exitCode, isNot(0));
    expect(await output.readAsString(), 'original');
  });
}
