import 'home_shell.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar_page.dart'; // Takvim ekranı

const supabaseUrl = 'https://gbjyauaknrfjixeanjnj.supabase.co';

const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdianlhdWFrbnJmaml4ZWFuam5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MzE3NzEsImV4cCI6MjA3MTAwNzc3MX0.0rAWnfAXSBLHv6u-yVDfx-nbzi_Uq2HKuh5d9xymdI8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acil Tip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const SignInPage() : const HomeShell();
  }
}

// --------------------- SIGN-IN ---------------------

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final mail = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> _signIn() async {
    if (busy) return;
    setState(() {
      busy = true;
      err = null;
    });
    final nav = Navigator.of(context);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: mail.text.trim(),
        password: pass.text,
      );
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _anon() async {
    if (busy) return;
    setState(() {
      busy = true;
      err = null;
    });
    final nav = Navigator.of(context);
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: mail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 8),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(err!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy ? null : _signIn,
            child: const Text('Giriş yap'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : _anon,
            child: const Text('Anonim giriş'),
          ),
        ],
      ),
    );
  }
}

// --------------------- HOME (GÜN DETAY) ---------------------

class HomePage extends StatefulWidget {
  final DateTime? initialDay;
  const HomePage({super.key, this.initialDay});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supa = Supabase.instance.client;
  late DateTime day;

  @override
  void initState() {
    super.initState();
    day = widget.initialDay ?? DateTime.now();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Stream<List<Map<String, dynamic>>> _streamForDay(DateTime d) {
    return supa.from('events').stream(primaryKey: ['id']).eq('date', _ymd(d));
  }

  Future<int> _workHours(DateTime d) async {
    final rows = await supa
        .from('v_day_summary')
        .select()
        .eq('date', _ymd(d))
        .eq('user_id', supa.auth.currentUser!.id);
    final list = rows as List;
    if (list.isEmpty) return 0;
    return (list.first['work_hours'] as num).toInt();
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    await supa.auth.signOut();
    nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) {
    return showTimePicker(
        context: context,
        initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0));
  }

  Future<void> _addOrEdit({Map<String, dynamic>? current}) async {
    final title = TextEditingController(text: current?['title'] ?? '');
    String type = (current?['type'] as String?) ?? 'etkinlik';
    TimeOfDay? start = (current?['start_time'] != null)
        ? _parseTime(current!['start_time'])
        : null;
    TimeOfDay? end = (current?['end_time'] != null)
        ? _parseTime(current!['end_time'])
        : null;
    final notes = TextEditingController(text: current?['notes'] ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom + 16;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current == null ? 'Yeni kayıt' : 'Kaydı düzenle',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 8),
              // Tür seçim çipleri
              Wrap(
                spacing: 8,
                children: [
                  _TypeChip(
                    label: 'Etkinlik',
                    selected: type == 'etkinlik',
                    icon: Icons.event,
                    onTap: () => type = 'etkinlik',
                  ),
                  _TypeChip(
                    label: 'Nöbet',
                    selected: type == 'nobet',
                    icon: Icons.local_hospital,
                    onTap: () => type = 'nobet',
                  ),
                  _TypeChip(
                    label: 'Eğitim',
                    selected: type == 'egitim',
                    icon: Icons.menu_book,
                    onTap: () => type = 'egitim',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await _pickTime(start);
                        if (t != null) setState(() => start = t);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(start == null ? 'Başlangıç' : _fmt(start!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await _pickTime(end);
                        if (t != null) setState(() => end = t);
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(end == null ? 'Bitiş' : _fmt(end!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (saved != true) return;

    final uid = supa.auth.currentUser?.id ??
        (await supa.auth.signInAnonymously()).user!.id;
    final payload = {
      'user_id': uid,
      'date': _ymd(day),
      'title': title.text.trim(),
      'type': type,
      'start_time': start == null ? null : _fmt(start!),
      'end_time': end == null ? null : _fmt(end!),
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    };

    if (current == null) {
      await supa.from('events').insert(payload);
    } else {
      await supa.from('events').update(payload).eq('id', current['id']);
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ymd = _ymd(day);
    final titleYmd = DateFormat('yyyy-MM-dd').format(day);

    return Scaffold(
      appBar: AppBar(
        title: Text('Acil Tip – $titleYmd'),
        actions: [
          IconButton(
            tooltip: 'Takvim',
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CalendarPage(),
              ));
            },
          ),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni kayıt'),
      ),
      body: Column(
        children: [
          // Üst bilgi satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Text(
                  DateFormat('d MMMM yyyy', 'tr_TR').format(day),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(width: 8),
                if (!DateUtils.isSameDay(day, DateTime.now()))
                  OutlinedButton(
                    onPressed: () => setState(() => day = DateTime.now()),
                    child: const Text('Bugün'),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(
                      () => day = day.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => day = day.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          // Günlük saat özeti
          FutureBuilder<int>(
            future: supa.auth.currentUser == null
                ? Future.value(0)
                : _workHours(day),
            builder: (context, snap) {
              final hours = snap.data ?? 0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      Text('Günlük çalışma saati: $hours'),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          // Kayıtlar
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(ymd),
              stream: _streamForDay(day),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }
                final rows = (snap.data ?? []);
                if (rows.isEmpty) {
                  return Center(
                    child: Text('$ymd için kayıt yok',
                        style: const TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final type = r['type'] ?? 'etkinlik';
                    final icon = switch (type) {
                      'nobet' => Icons.local_hospital,
                      'egitim' => Icons.menu_book,
                      _ => Icons.event
                    };
                    final chipColor = switch (type) {
                      'nobet' => const Color(0xFFFFEEF0),
                      'egitim' => const Color(0xFFEFF6FF),
                      _ => const Color(0xFFF5F5F5)
                    };

                    return Dismissible(
                      key: ValueKey(r['id']),
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onDismissed: (_) =>
                          supa.from('events').delete().eq('id', r['id']),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _addOrEdit(current: r),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: chipColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: -6,
                                        children: [
                                          _MiniChip(
                                              label: (r['type'] ?? 'etkinlik')
                                                  as String),
                                          if ((r['start_time'] ?? '') != '' ||
                                              (r['end_time'] ?? '') != '')
                                            _MiniChip(
                                              label:
                                                  '${(r['start_time'] ?? '')} – ${(r['end_time'] ?? '')}',
                                              icon: Icons.schedule,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  r['date'] ?? '',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _MiniChip({required this.label, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.selected,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ]),
      onSelected: (_) => onTap(),
    );
  }
}
