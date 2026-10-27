part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 1) Brand
// ---------------------------------------------------------------------------

class _BrandStep extends StatefulWidget {
  const _BrandStep({
    super.key,
    required this.brands,
    required this.selectedId,
    required this.isArabic,
    required this.onSelected,
  });

  final List<VehicleBrand> brands;
  final String? selectedId;
  final bool isArabic;
  final ValueChanged<VehicleBrand> onSelected;

  @override
  State<_BrandStep> createState() => _BrandStepState();
}

class _BrandStepState extends State<_BrandStep> {
  // البحث محلي هنا كي لا يعيد كل حرف بناء المعالج بأكمله.
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
    final filtered = normalized.isEmpty
        ? widget.brands
        : widget.brands
            .where((brand) =>
                brand.nameAr.toLowerCase().contains(normalized) ||
                brand.nameEn.toLowerCase().contains(normalized))
            .toList(growable: false);

    if (filtered.isEmpty) {
      return CustomScrollView(
        slivers: [
          _searchSliver(l10n),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              label: l10n?.vehicleNoResults ?? 'لا توجد نتائج',
            ),
          ),
        ],
      );
    }

    final popular = normalized.isEmpty
        ? filtered.where((brand) => brand.isPopular).toList(growable: false)
        : const <VehicleBrand>[];
    final all = [...filtered]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return CustomScrollView(
      slivers: [
        _searchSliver(l10n),
        if (popular.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          _titleSliver(l10n?.vehiclePopularBrands ?? 'الأكثر انتشارًا'),
          _gridSliver(popular),
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: popular.isNotEmpty ? 18 : 14),
        ),
        _titleSliver(l10n?.vehicleAllBrands ?? 'كل الماركات'),
        _gridSliver(all),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _searchSliver(AppLocalizations? l10n) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverToBoxAdapter(
        child: _SearchField(
          controller: _controller,
          hint: l10n?.vehicleSearchBrand ?? 'ابحث عن ماركة',
          onChanged: () => setState(() => _query = _controller.text),
        ),
      ),
    );
  }

  Widget _titleSliver(String label) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(child: _SectionTitle(label)),
    );
  }

  /// شبكة كسولة: تُبنى بطاقات الماركات الظاهرة فقط، فلا تُحلَّل 25 صورة
  /// SVG مرة واحدة عند فتح الخطوة.
  Widget _gridSliver(List<VehicleBrand> brands) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final brand = brands[index];
            return _BrandCard(
              brand: brand,
              selected: brand.id == widget.selectedId,
              isArabic: widget.isArabic,
              onTap: () => widget.onSelected(brand),
            );
          },
          childCount: brands.length,
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.brand,
    required this.selected,
    required this.isArabic,
    required this.onTap,
  });

  final VehicleBrand brand;
  final bool selected;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.orangePrimary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandLogo(brand: brand, size: 44, padding: 7),
              const SizedBox(height: 8),
              Text(
                brand.name(isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
