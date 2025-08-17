// lib/calendar_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aciltip/main.dart' show HomePage;

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final supa = Supabase.instance.client;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selected;
  // yyyy-MM-dd -> olay listesi (yalnızca başlık & tip saklıyoruz)
  Map<String, List<Map<String, dynamic>>> _events = {};

  // Hızlı ekleme
  final _input = TextEditingController();
  final _hints = <String>[
    'Bugün 09:00 vizit ekle',
    '14’üne nöbet ekle',
    'Yarın eğitim ekle',
    'Toplantı 10:30 ekle',
  ];
  int _hintIx = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _hintIx = (_hintIx + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  // ---------------- data ----------------
  Future<void> _loadMonth() async {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0);
    final s = DateFormat('yyyy-MM-dd').format(start);
    final e = DateFormat('yyyy-MM-dd').format(end);

    final rows = await supa
        .from('events')
        .select('date,title,type')
        .gte('date', s)
        .lte('date', e)
        .order('date');

    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in (rows as List)) {
      final d = r['date'] as String;
      (map[d] ??= []).add({
        'title': r['title'],
        'type': r['type'],
      });
    }
    setState(() => _events = map);
  }

  // ---------------- helpers ----------------
  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _selected = null;
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _selected = null;
    });
    _loadMonth();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------- quick add ----------------
  Future<void> _quickAdd() async {
    final txt = _input.text.trim();
    if (txt.isEmpty) return;

    // tarih çöz
    final date = _parseDate(txt) ?? _selected ?? DateTime.now();

    // tip & başlık
    String type = 'etkinlik';
    if (_contains(txt, 'nöbet', 'nobet')) type = 'nobet';
    if (_contains(txt, 'eğitim', 'egitim')) type = 'egitim';
    final title = _extractTitle(txt);

    // saatler
    final times = RegExp(r'(\d{1,2})[:\.](\d{2})')
        .allMatches(txt)
        .map((m) => TimeOfDay(
              hour: int.parse(m.group(1)!),
              minute: int.parse(m.group(2)!),
            ))
        .toList();
    String? start, end;
    if (times.length == 2) {
      start = _fmt(times.first);
      end = _fmt(times.last);
    } else if (type == 'nobet') {
      start = '08:00';
      end = '20:00';
    }

    final uid = supa.auth.currentUser?.id ??
        (await supa.auth.signInAnonymously()).user!.id;

    await supa.from('events').insert({
      'user_id': uid,
      'date': _ymd(date),
      'title': title,
      'type': type,
      'start_time': start,
      'end_time': end,
    });

    _input.clear();

    // aynı ay ise önizlemeyi güncelle
    if (date.year == _month.year && date.month == _month.month) {
      final k = _ymd(date);
      (_events[k] ??= []).insert(0, {'title': title, 'type': type});
      setState(() {});
    }
  }

  bool _contains(String s, String a, [String? b]) {
    final low = s.toLowerCase();
    return low.contains(a) || (b != null && low.contains(b));
  }

  DateTime? _parseDate(String s) {
    final low = s.toLowerCase();
    if (low.contains('bugün') || low.contains('bugun')) return DateTime.now();
    if (low.contains('yarın') || low.contains('yarin')) {
      final t = DateTime.now();
      return t.add(const Duration(days: 1));
    }
    final m = RegExp(r'(\d{1,2})').firstMatch(low);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final last = DateTime(_month.year, _month.month + 1, 0).day;
      if (d >= 1 && d <= last) {
        return DateTime(_month.year, _month.month, d);
      }
    }
    return null;
  }

  String _extractTitle(String s) {
    var t = s;
    for (final k in [
      'ekle',
      'ekleyin',
      'bugün',
      'bugun',
      'yarın',
      'yarin',
      'nöbet',
      'nobet',
      'eğitim',
      'egitim'
    ]) {
      t = t.replaceAll(RegExp('\\b$k\\b', caseSensitive: false), '');
    }
    t = t.replaceAll(RegExp(r'\b\d{1,2}\b'), '');
    t = t.replaceAll(RegExp(r'\d{1,2}[:\.]\d{2}'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) {
      if (_contains(s, 'nöbet', 'nobet')) return 'Nöbet';
      if (_contains(s, 'eğitim', 'egitim')) return 'Eğitim';
      return 'Etkinlik';
    }
    return t[0].toUpperCase() + t.substring(1);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1-7
    final leading = (firstWeekday + 6) % 7; // pazartesi=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final total = leading + daysInMonth;
    final rows = (total / 7).ceil();

    final firstCellDate = DateTime(_month.year, _month.month, 1)
        .subtract(Duration(days: leading));

    final monthTitleRaw = DateFormat('LLLL yyyy', 'tr_TR').format(_month);
    final monthTitle =
        toBeginningOfSentenceCase(monthTitleRaw) ?? monthTitleRaw;

    // hızlı ekleme placeholder’ı (seçili gün kısa biçim)
    final selLabel = _selected == null
        ? _hints[_hintIx]
        : '${DateFormat("d MMM", "tr_TR").format(_selected!)} etkinlik ekle';

    return Scaffold(
      body: Column(
        children: [
          // Ay başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                ),
                Expanded(
                  child: Text(
                    monthTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Haftanın günleri
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: const [
                _Weekday('Pzt'),
                _Weekday('Sal'),
                _Weekday('Çar'),
                _Weekday('Per'),
                _Weekday('Cum'),
                _Weekday('Cmt', weekend: true),
                _Weekday('Pzr', weekend: true),
              ],
            ),
          ),

          // Haftalar
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: rows,
              itemBuilder: (context, rowIx) {
                final rowChildren = <Widget>[];
                for (int col = 0; col < 7; col++) {
                  final idx = rowIx * 7 + col;
                  final d = firstCellDate.add(Duration(days: idx));
                  final inMonth = d.month == _month.month;
                  final isWeekend = d.weekday == DateTime.saturday ||
                      d.weekday == DateTime.sunday;
                  final isSelected = _selected != null &&
                      d.year == _selected!.year &&
                      d.month == _selected!.month &&
                      d.day == _selected!.day;
                  final ymd = _ymd(d);
                  final dayEvents = _events[ymd] ?? const [];

                  rowChildren.add(
                    Expanded(
                      child: _DayTile(
                        date: d,
                        inMonth: inMonth,
                        weekend: isWeekend,
                        selected: isSelected,
                        preview: dayEvents.isEmpty
                            ? null
                            : (dayEvents.first['title'] as String?) ?? '',
                        onTap: () => setState(() => _selected = d),
                        onOpen: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HomePage(initialDay: d),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(children: rowChildren),
                    if (rowIx != rows - 1)
                      const Divider(
                          height: 18, thickness: 1, color: Color(0xFFEAEAEA)),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // Alt hızlı ekleme alanı
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: selLabel,
                filled: true,
                fillColor: const Color(0xFFF1F2F4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _quickAdd(),
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _quickAdd,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------- small widgets ----------------

class _Weekday extends StatelessWidget {
  final String label;
  final bool weekend;
  const _Weekday(this.label, {this.weekend = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: weekend ? const Color(0xFFE11D48) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool weekend;
  final bool selected;
  final String? preview;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  const _DayTile({
    required this.date,
    required this.inMonth,
    required this.weekend,
    required this.selected,
    required this.preview,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF9CA3AF) : const Color(0xFFE5E7EB);
    final dayNum = date.day.toString();

    final dayColor = !inMonth
        ? const Color(0xFFBDBDBD)
        : (weekend ? const Color(0xFFE11D48) : const Color(0xFF111827));

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      onLongPress: onOpen,
      child: Container(
        height: 86,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // gün numarası (seçiliyse küçük kırmızı kapsül)
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(dayNum,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              )
            else
              Text(dayNum,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: dayColor,
                  )),

            const SizedBox(height: 6),

            // tek satır önizleme (küçük mavi şerit + metin)
            if (preview != null && preview!.isNotEmpty)
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C9DFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      preview!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: inMonth
                            ? const Color(0xFF374151)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}
