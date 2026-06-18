import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class FormatUtils {
  static String _locale(BuildContext context) => context.locale.toLanguageTag();

  static String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'TND':
        return 'DT';
      case 'EUR':
        return '€';
      case 'USD':
        return r'$';
      default:
        return code.toUpperCase();
    }
  }

  static String money(
    BuildContext context,
    num? value, {
    String currencyCode = 'TND',
    int decimalDigits = 2,
  }) {
    final v = (value ?? 0).toDouble();
    final code = currencyCode.isEmpty ? 'TND' : currencyCode.toUpperCase();
    final symbol = _currencySymbol(code);
    return NumberFormat.currency(
      locale: _locale(context),
      name: code,
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(v);
  }

  static String number(
    BuildContext context,
    num? value, {
    int decimalDigits = 0,
  }) {
    final v = (value ?? 0).toDouble();
    final f = NumberFormat.decimalPattern(_locale(context))
      ..minimumFractionDigits = decimalDigits
      ..maximumFractionDigits = decimalDigits;
    return f.format(v);
  }

  static String percent(
    BuildContext context,
    num? ratio, {
    int decimalDigits = 0,
  }) {
    final v = ((ratio ?? 0) * 100).toDouble();
    final formatted = number(context, v, decimalDigits: decimalDigits);
    return '$formatted%';
  }

  static DateTime? tryParseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String dateTime(BuildContext context, DateTime? value) {
    if (value == null) return '';
    return DateFormat.yMMMd(_locale(context)).add_Hm().format(value.toLocal());
  }
}
