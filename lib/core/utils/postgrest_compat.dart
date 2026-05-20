import 'package:supabase_flutter/supabase_flutter.dart';

bool isMissingColumnError(
  Object error, {
  required String column,
  String? table,
}) {
  if (error is! PostgrestException) {
    return false;
  }

  final message = error.message.toLowerCase();
  final normalizedColumn = column.toLowerCase();
  final normalizedTable = table?.toLowerCase();
  final missingColumnCode = error.code == '42703' || error.code == 'PGRST204';
  final missingColumnMessage =
      message.contains('does not exist') || message.contains('could not find');

  if (!message.contains(normalizedColumn)) {
    return false;
  }
  if (normalizedTable != null && !message.contains(normalizedTable)) {
    return false;
  }

  return missingColumnCode || missingColumnMessage;
}
