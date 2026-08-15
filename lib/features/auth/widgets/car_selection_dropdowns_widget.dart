import 'dart:convert';
import 'package:flutter/material.dart';

class CarSelectionDropdownsWidget extends StatefulWidget {
  final Function(String? make, String? model, String? year) onChanged;

  const CarSelectionDropdownsWidget({super.key, required this.onChanged});

  @override
  State<CarSelectionDropdownsWidget> createState() =>
      _CarSelectionDropdownsWidgetState();
}

class _CarSelectionDropdownsWidgetState
    extends State<CarSelectionDropdownsWidget> {
  Map<String, dynamic> _carBrandsData = {};
  bool _isLoading = true;

  String? _selectedMake;
  String? _selectedModel;
  String? _selectedYear;

  List<String> _makes = [];
  List<String> _models = [];
  List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _loadCarBrands();
  }

  Future<void> _loadCarBrands() async {
    try {
      final jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/data/car_brands.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      setState(() {
        _carBrandsData = data;
        _makes = data.keys.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMakeChanged(String? make) {
    setState(() {
      _selectedMake = make;
      _selectedModel = null;
      _selectedYear = null;
      _models = [];
      _years = [];

      if (make != null && _carBrandsData.containsKey(make)) {
        final Map<String, dynamic> modelsMap =
            _carBrandsData[make] as Map<String, dynamic>;
        _models = modelsMap.keys.toList();
      }
    });
    widget.onChanged(_selectedMake, _selectedModel, _selectedYear);
  }

  void _onModelChanged(String? model) {
    setState(() {
      _selectedModel = model;
      _selectedYear = null;
      _years = [];

      if (_selectedMake != null &&
          model != null &&
          _carBrandsData.containsKey(_selectedMake)) {
        final Map<String, dynamic> modelsMap =
            _carBrandsData[_selectedMake] as Map<String, dynamic>;
        if (modelsMap.containsKey(model)) {
          final List<dynamic> yearsList = modelsMap[model] as List<dynamic>;
          _years = yearsList.map((e) => e.toString()).toList();
        }
      }
    });
    widget.onChanged(_selectedMake, _selectedModel, _selectedYear);
  }

  void _onYearChanged(String? year) {
    setState(() {
      _selectedYear = year;
    });
    widget.onChanged(_selectedMake, _selectedModel, _selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'بيانات السيارة (إجباري)',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 12),

        // Car Make Dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedMake,
          decoration: InputDecoration(
            labelText: 'نوع السيارة (الماركة)',
            prefixIcon:
                const Icon(Icons.time_to_leave_rounded, color: Color(0xFFFF6B00)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _makes.map((make) {
            return DropdownMenuItem<String>(
              value: make,
              child: Text(make, style: const TextStyle(fontFamily: 'Cairo')),
            );
          }).toList(),
          onChanged: _onMakeChanged,
          validator: (value) => value == null ? 'يرجى اختيار ماركة السيارة' : null,
        ),
        const SizedBox(height: 14),

        // Car Model Dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          disabledHint: const Text('اختر ماركة السيارة أولاً',
              style: TextStyle(fontFamily: 'Cairo')),
          decoration: InputDecoration(
            labelText: 'موديل السيارة',
            prefixIcon: const Icon(Icons.car_repair_rounded,
                color: Color(0xFFFF6B00)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _models.map((model) {
            return DropdownMenuItem<String>(
              value: model,
              child: Text(model, style: const TextStyle(fontFamily: 'Cairo')),
            );
          }).toList(),
          onChanged: _selectedMake == null ? null : _onModelChanged,
          validator: (value) => value == null ? 'يرجى اختيار موديل السيارة' : null,
        ),
        const SizedBox(height: 14),

        // Car Year Dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedYear,
          disabledHint: const Text('اختر الموديل أولاً',
              style: TextStyle(fontFamily: 'Cairo')),
          decoration: InputDecoration(
            labelText: 'سنة الصنع',
            prefixIcon:
                const Icon(Icons.calendar_today_rounded, color: Color(0xFFFF6B00)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _years.map((year) {
            return DropdownMenuItem<String>(
              value: year,
              child: Text(year, style: const TextStyle(fontFamily: 'Cairo')),
            );
          }).toList(),
          onChanged: _selectedModel == null ? null : _onYearChanged,
          validator: (value) => value == null ? 'يرجى اختيار سنة الصنع' : null,
        ),
      ],
    );
  }
}
