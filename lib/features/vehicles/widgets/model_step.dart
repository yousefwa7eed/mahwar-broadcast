part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 2) Model
// ---------------------------------------------------------------------------

class _ModelStep extends StatefulWidget {
  const _ModelStep({
    super.key,
    required this.brand,
    required this.selectedId,
    required this.isArabic,
    required this.onSelected,
  });

  final VehicleBrand brand;
  final String? selectedId;
  final bool isArabic;
  final ValueChanged<VehicleModel> onSelected;

  @override
  State<_ModelStep> createState() => _ModelStepState();
}

class _ModelStepState extends State<_ModelStep> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = _query.trim().toLowerCase();
    final models = (normalized.isEmpty
            ? widget.brand.models
            : widget.brand.models
                .where((model) =>
                    model.nameAr.toLowerCase().contains(normalized) ||
                    model.nameEn.toLowerCase().contains(normalized))
                .toList(growable: false))
        .toList(growable: false);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: models.isEmpty ? 2 : models.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SearchField(
              controller: _controller,
              hint: l10n?.vehicleSearchModel ?? 'ابحث عن موديل',
              onChanged: () => setState(() => _query = _controller.text),
            ),
          );
        }
        if (models.isEmpty) {
          return _EmptyState(
            label: l10n?.vehicleNoResults ?? 'لا توجد نتائج',
          );
        }
        final model = models[index - 1];
        return _OptionTile(
          title: model.name(widget.isArabic),
          subtitle: vehicleBodyTypeLabel(model.bodyType, l10n),
          selected: model.id == widget.selectedId,
          leading: BrandLogo(brand: widget.brand, size: 40, padding: 6),
          onTap: () => widget.onSelected(model),
        );
      },
    );
  }
}
