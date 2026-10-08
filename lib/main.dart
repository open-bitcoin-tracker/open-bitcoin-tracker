import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'services/app_orientation.dart';
export 'app/app.dart' show OpenBitcoinTrackerApp;
export 'services/app_orientation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(kDefaultOrientations);
  // Load symbols for every locale we ship so DateFormat doesn't throw on the
  // first language switch. Cheap (kilobytes), simpler than re-loading on swap.
  await initializeDateFormatting('en_GB');
  await initializeDateFormatting('es_ES');
  final prefs = await SharedPreferences.getInstance();
  runApp(OpenBitcoinTrackerApp(prefs: prefs));
}
