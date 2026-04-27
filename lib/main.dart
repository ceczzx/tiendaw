import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/app/system_w_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final bootstrapError = await _bootstrapSupabase();

  runApp(
    ProviderScope(child: SystemWApp(bootstrapError: bootstrapError)),
  );
}

Future<String?> _bootstrapSupabase() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  if (_isPlaceholder(supabaseUrl) || _isPlaceholder(supabaseAnonKey)) {
    return 'Completa SUPABASE_URL y SUPABASE_ANON_KEY en el archivo .env para conectar la app.';
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  return null;
}

bool _isPlaceholder(String value) {
  return value.isEmpty || value.contains('YOUR-PROJECT') || value.contains('YOUR_SUPABASE');
}
