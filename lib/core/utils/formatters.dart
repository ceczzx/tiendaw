import 'package:intl/intl.dart';

abstract final class SystemWFormatters {
  static final currency = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
  );

  static final shortDate = DateFormat('dd/MM/yyyy');
  static final shortDateTime = DateFormat('dd/MM HH:mm');
}
