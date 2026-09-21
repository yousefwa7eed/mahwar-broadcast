import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _DaySchedule {
  bool isClosed;
  TimeOfDay? open;
  TimeOfDay? close;

  _DaySchedule({this.isClosed = false, this.open, this.close});
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  static const List<String> _arDays = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];
  static const List<String> _enDays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  static const TimeOfDay _defaultOpen = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay _defaultClose = TimeOfDay(hour: 17, minute: 0);

  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  // الجدول الموحّد الذي نطبّقه على كل الأيام دفعة واحدة.
  TimeOfDay? _uniformOpen = _defaultOpen;
  TimeOfDay? _uniformClose = _defaultClose;

  late final Map<int, _DaySchedule> _days = {
    for (var i = 0; i < 7; i++)
      i: _DaySchedule(open: _defaultOpen, close: _defaultClose),
  };

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('provider_schedules')
          .select('day_of_week, open_time, close_time, is_closed')
          .eq('provider_id', userId);

      if (mounted) {
        setState(() {
          for (final row in response) {
            final day = (row['day_of_week'] as num?)?.toInt() ?? 0;
            if (day < 0 || day > 6) continue;
            final isClosed = row['is_closed'] ?? false;
            _days[day] = _DaySchedule(
              isClosed: isClosed == true,
              open: isClosed == true ? null : _parseDbTime(row['open_time']),
              close: isClosed == true ? null : _parseDbTime(row['close_time']),
            );
          }
          _uniformOpen = _mostCommonOpen();
          _uniformClose = _mostCommonClose();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _parseDbTime(dynamic value) {
    if (value == null) return null;
    final parts = value.toString().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _toDbTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  // أكثر وقت (بداية/نهاية) تكراراً بين الأيام المفتوحة — يُعتبر الجدول الموحّد.
  TimeOfDay? _mostCommonOpen() {
    final counts = <String, int>{};
    for (final day in _days.values) {
      if (day.isClosed || day.open == null) continue;
      final key = '${_minutesOf(day.open!)}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return _fromKey(counts);
  }

  TimeOfDay? _mostCommonClose() {
    final counts = <String, int>{};
    for (final day in _days.values) {
      if (day.isClosed || day.close == null) continue;
      final key = '${_minutesOf(day.close!)}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return _fromKey(counts);
  }

  TimeOfDay? _fromKey(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final minutes = int.tryParse(best);
    if (minutes == null) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  bool _isUniform(_DaySchedule day) {
    if (day.isClosed || day.open == null || day.close == null) return false;
    if (_uniformOpen == null || _uniformClose == null) return false;
    return _minutesOf(day.open!) == _minutesOf(_uniformOpen!) &&
        _minutesOf(day.close!) == _minutesOf(_uniformClose!);
  }

  void _applyToAllDays() {
    final open = _uniformOpen;
    final close = _uniformClose;
    if (open == null || close == null) return;
    setState(() {
      for (final day in _days.values) {
        day
          ..isClosed = false
          ..open = open
          ..close = close;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'تم تطبيق الجدول على جميع الأيام'
                : 'Applied to all days',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  void _restoreDay(int index) {
    final open = _uniformOpen;
    final close = _uniformClose;
    if (open == null || close == null) return;
    setState(() {
      _days[index]!
        ..isClosed = false
        ..open = open
        ..close = close;
    });
  }

  Future<void> _pickTime(int day, {required bool isOpen}) async {
    final current = isOpen ? _days[day]!.open : _days[day]!.close;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? _defaultOpen,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOpen) {
          _days[day]!.open = picked;
        } else {
          _days[day]!.close = picked;
        }
      });
    }
  }

  Future<void> _pickUniformTime({required bool isOpen}) async {
    final current = isOpen ? _uniformOpen : _uniformClose;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? _defaultOpen,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOpen) {
          _uniformOpen = picked;
        } else {
          _uniformClose = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    for (final day in _days.values) {
      if (day.isClosed) continue;
      if (day.open == null || day.close == null) {
        _showError(l10n?.workingHoursSetTimes ??
            (isArabic ? 'يرجى تحديد وقت بداية ونهاية العمل' : 'Please set both open and close times'));
        return;
      }
      if (_minutesOf(day.close!) <= _minutesOf(day.open!)) {
        _showError(l10n?.workingHoursInvalidRange ??
            (isArabic ? 'يجب أن يكون وقت البداية قبل وقت النهاية' : 'Open time must be before close time'));
        return;
      }
    }

    setState(() => _isSaving = true);

    final rows = _days.entries.map((entry) {
      final day = entry.value;
      return {
        'provider_id': userId,
        'day_of_week': entry.key,
        'is_closed': day.isClosed,
        'open_time': day.isClosed ? null : _toDbTime(day.open!),
        'close_time': day.isClosed ? null : _toDbTime(day.close!),
      };
    }).toList();

    try {
      await _client
          .from('provider_schedules')
          .upsert(rows, onConflict: 'provider_id,day_of_week');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.savedSuccessfully ?? 'تم الحفظ بنجاح',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showError(isArabic ? 'حدث خطأ أثناء الحفظ: $e' : 'Error saving: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  int _todayDow() {
    final dartWeekday = DateTime.now().weekday; // 1 = Monday .. 7 = Sunday
    return dartWeekday == 7 ? 0 : dartWeekday;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.workingHours ?? 'ساعات العمل',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.orangePrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.workingHoursHint ?? 'حدد ساعات عملك — خارج هذه الساعات لن تظهر في قائمة المزودين المتاحين',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildUniformCard(isDark: isDark, isArabic: isArabic),
                      const SizedBox(height: 20),
                      Text(
                        isArabic ? 'الأيام الاستثنائية' : 'Daily exceptions',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isArabic
                            ? 'عطّل يوماً أو عدّل وقته — باقي الأيام تتبع الجدول الموحّد'
                            : 'Turn a day off or edit its time — the rest follow the unified schedule',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < 7; i++) ...[
                        _buildDayRow(index: i, day: _days[i]!, isDark: isDark, isArabic: isArabic),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orangePrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              l10n?.savedSuccessfully ?? 'حفظ التعديلات',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUniformCard({required bool isDark, required bool isArabic}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangePrimary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded, size: 18, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'الجدول الموحّد لجميع الأيام' : 'One schedule for all days',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'حدّد موعداً واحداً وطبّقه على كل أيام الأسبوع، ثم استثنِ بعدها ما تريد'
                : 'Set a single time and apply it to every day, then adjust exceptions below',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeButton(
                  label: isArabic ? 'بداية العمل' : 'Open at',
                  time: _uniformOpen,
                  isDark: isDark,
                  onTap: () => _pickUniformTime(isOpen: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeButton(
                  label: isArabic ? 'نهاية العمل' : 'Close at',
                  time: _uniformClose,
                  isDark: isDark,
                  onTap: () => _pickUniformTime(isOpen: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uniformOpen == null || _uniformClose == null ? null : _applyToAllDays,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orangePrimary,
                side: BorderSide(color: AppColors.orangePrimary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: Text(
                isArabic ? 'تطبيق على جميع الأيام' : 'Apply to all days',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow({
    required int index,
    required _DaySchedule day,
    required bool isDark,
    required bool isArabic,
  }) {
    final isToday = index == _todayDow();
    final isUniform = _isUniform(day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppColors.orangePrimary
              : isDark
                  ? AppColors.darkBorder
                  : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.orangePrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isArabic ? 'اليوم' : 'Today',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
                  Text(
                    (isArabic ? _arDays : _enDays)[index],
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (!day.isClosed && !isUniform)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppColors.orangePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isArabic ? 'خاص' : 'Custom',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
                  Text(
                    day.isClosed
                        ? (isArabic ? 'إجازة' : 'Day off')
                        : (isArabic ? 'متاح' : 'Available'),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: day.isClosed ? AppColors.error : AppColors.success,
                    ),
                  ),
                  Switch(
                    value: day.isClosed,
                    activeTrackColor: AppColors.error,
                    onChanged: (val) => setState(() {
                      _days[index]!.isClosed = val;
                      // عند إعادة فتح يوم كان مغلقاً نملأه بالجدول الموحّد مباشرة.
                      if (!val && _days[index]!.open == null) {
                        _days[index]!
                          ..open = _uniformOpen
                          ..close = _uniformClose;
                      }
                    }),
                  ),
                ],
              ),
            ],
          ),
          if (!day.isClosed) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    label: isArabic ? 'بداية العمل' : 'Open at',
                    time: day.open,
                    isDark: isDark,
                    onTap: () => _pickTime(index, isOpen: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTimeButton(
                    label: isArabic ? 'نهاية العمل' : 'Close at',
                    time: day.close,
                    isDark: isDark,
                    onTap: () => _pickTime(index, isOpen: false),
                  ),
                ),
              ],
            ),
            if (!isUniform && _uniformOpen != null && _uniformClose != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _restoreDay(index),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.orangePrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: Text(
                    isArabic ? 'استعادة الجدول الموحّد' : 'Restore unified time',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? time,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time == null
                      ? '--:--'
                      : MaterialLocalizations.of(context).formatTimeOfDay(time),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: time == null
                        ? AppColors.error
                        : isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                  ),
                ),
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.orangePrimary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}