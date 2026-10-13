import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Round for display. Default: one decimal below 100, none above, because
/// three decimals of humidity is noise at arm's length.
String fmt(num? n, [int? decimals]) {
  if (n == null) return '—';
  final d = decimals ?? ((n.abs() >= 100 || n == n.roundToDouble()) ? 0 : 1);
  return n.toStringAsFixed(d);
}

String fmtLocale(BuildContext context, num? n, [int? decimals]) {
  if (n == null) return '—';
  final d = decimals ?? ((n.abs() >= 100 || n == n.roundToDouble()) ? 0 : 1);
  return NumberFormat.decimalPatternDigits(
    locale: Localizations.localeOf(context).toLanguageTag(),
    decimalDigits: d,
  ).format(n);
}

String capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
