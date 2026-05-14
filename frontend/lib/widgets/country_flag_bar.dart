import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

const Map<String, String> _countryFlags = {
  'Tunisia': '\u{1F1F9}\u{1F1F3}',
  'France': '\u{1F1EB}\u{1F1F7}',
  'Algeria': '\u{1F1E9}\u{1F1FF}',
  'Morocco': '\u{1F1F2}\u{1F1E6}',
  'United States': '\u{1F1FA}\u{1F1F8}',
  'Canada': '\u{1F1E8}\u{1F1E6}',
  'United Kingdom': '\u{1F1EC}\u{1F1E7}',
  'Germany': '\u{1F1E9}\u{1F1EA}',
  'Italy': '\u{1F1EE}\u{1F1F9}',
  'Spain': '\u{1F1EA}\u{1F1F8}',
  'Belgium': '\u{1F1E7}\u{1F1EA}',
  'Switzerland': '\u{1F1E8}\u{1F1ED}',
  'Netherlands': '\u{1F1F3}\u{1F1F1}',
  'China': '\u{1F1E8}\u{1F1F3}',
  'Japan': '\u{1F1EF}\u{1F1F5}',
  'South Korea': '\u{1F1F0}\u{1F1F7}',
  'Brazil': '\u{1F1E7}\u{1F1F7}',
  'India': '\u{1F1EE}\u{1F1F3}',
  'Russia': '\u{1F1F7}\u{1F1FA}',
  'Australia': '\u{1F1E6}\u{1F1FA}',
  'Libya': '\u{1F1F1}\u{1F1FE}',
  'Egypt': '\u{1F1EA}\u{1F1EC}',
  'Saudi Arabia': '\u{1F1F8}\u{1F1E6}',
  'United Arab Emirates': '\u{1F1E6}\u{1F1EA}',
  'Qatar': '\u{1F1F6}\u{1F1E6}',
  'Turkey': '\u{1F1F9}\u{1F1F7}',
};

String flagForCountry(String country) {
  return _countryFlags[country] ?? '\u{1F30D}';
}

class CountryFlagBar extends StatelessWidget {
  final String country;
  final int count;
  final int maxCount;
  final Color barColor;

  const CountryFlagBar({
    super.key,
    required this.country,
    required this.count,
    required this.maxCount,
    this.barColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxCount > 0 ? count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Text(flagForCountry(country), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text(country,
                    style: AppTypography.body2,
                    overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              Text('$count',
                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: AppTypography.caption,
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
