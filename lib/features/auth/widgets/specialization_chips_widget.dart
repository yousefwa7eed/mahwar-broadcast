import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class SpecializationChipsWidget extends StatelessWidget {
  final List<String> selectedSpecializations;
  final ValueChanged<List<String>> onChanged;
  final bool isArabic;

  const SpecializationChipsWidget({
    super.key,
    required this.selectedSpecializations,
    required this.onChanged,
    this.isArabic = true,
  });

  static const List<Map<String, String>> specializationsList = [
    {'id': 'crane', 'ar': 'ونش طوارئ S.O.S', 'en': 'Tow Truck Crane S.O.S'},
    {'id': 'tire', 'ar': 'خدمات الإطارات', 'en': 'Tire Services'},
    {'id': 'battery', 'ar': 'بطاريات / كهرباء', 'en': 'Battery & Electrical'},
    {'id': 'fuel', 'ar': 'تزويد بنزين', 'en': 'Fuel Delivery'},
    {'id': 'mechanical', 'ar': 'ميكانيكي طوارئ', 'en': 'Emergency Mechanic'},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: specializationsList.map((spec) {
            final id = spec['id']!;
            final label = switch (id) {
              'crane' => l10n?.specTowTruck ?? 'ونش طوارئ S.O.S',
              'tire' => l10n?.specTire ?? 'خدمات الإطارات',
              'battery' => l10n?.specBattery ?? 'بطاريات / كهرباء',
              'fuel' => l10n?.specFuel ?? 'تزويد بنزين',
              'mechanical' => l10n?.specMechanical ?? 'ميكانيكي طوارئ',
              _ => isArabic ? spec['ar']! : spec['en']!,
            };
            final isSelected = selectedSpecializations.contains(id);

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                final updated = List<String>.from(selectedSpecializations);
                if (selected) {
                  updated.add(id);
                } else {
                  updated.remove(id);
                }
                onChanged(updated);
              },
              selectedColor: const Color(0xFFFF6B00),
              checkmarkColor: Colors.white,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF6B00)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
