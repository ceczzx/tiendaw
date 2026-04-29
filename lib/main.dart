import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/app/system_w_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final bootstrapError = await _bootstrapSupabase();

  runApp(ProviderScope(child: SystemWApp(bootstrapError: bootstrapError)));
}

Future<String?> _bootstrapSupabase() async {
  final supabaseUrl = _readSupabaseUrl();
  final accessKey = _readSupabaseAccessKey();

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: accessKey);
    return null;
  } catch (error) {
    return 'No se pudo iniciar Supabase. Verifica que SUPABASE_URL apunte a la URL base del proyecto y que la clave publicada sea valida. Detalle: $error';
  }
}

String _readSupabaseUrl() {
  final rawUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  if (_isMissingValue(rawUrl)) {
    throw StateError(
      'Completa SUPABASE_URL en el archivo .env para conectar la app.',
    );
  }

  // Si por error pegan un endpoint interno como /auth/v1, lo llevamos
  // de vuelta a la raiz del proyecto sin tocar el formato normal.
  final sanitizedUrl = rawUrl.replaceFirst(
    RegExp(
      r'/(auth|rest|storage|realtime|functions)/v1/?$',
      caseSensitive: false,
    ),
    '',
  );

  final parsedUrl = Uri.tryParse(sanitizedUrl);
  if (parsedUrl == null || !parsedUrl.hasScheme || parsedUrl.host.isEmpty) {
    throw StateError(
      'SUPABASE_URL no tiene un formato valido. Usa la URL base del proyecto, por ejemplo https://tu-proyecto.supabase.co',
    );
  }

  return parsedUrl.origin;
}

String _readSupabaseAccessKey() {
  final accessKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ??
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ??
      '';

  if (_isMissingValue(accessKey)) {
    throw StateError(
      'Completa SUPABASE_PUBLISHABLE_KEY o SUPABASE_ANON_KEY en el archivo .env para conectar la app.',
    );
  }

  return accessKey;
}

bool _isMissingValue(String value) {
  return value.isEmpty ||
      value.contains('YOUR-PROJECT') ||
      value.contains('YOUR_SUPABASE');
}
