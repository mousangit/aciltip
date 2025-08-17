// lib/home_shell.dart
import 'package:flutter/material.dart';
import 'calendar_page.dart';
import 'main.dart' show HomePage; // Takvim dışındaki örnek içerik için

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Sekmeler
  static const _tabs = ['TAKVİM', 'ACİL', 'İLAÇ', 'ANTİDOT', 'HESAP'];

  Widget _buildPage(int i) {
    switch (i) {
      case 0:
        return const CalendarPage(); // Takvim
      case 1:
        return const _PlaceholderPage(title: 'Acil'); // İçerik sizde
      case 2:
        return const _PlaceholderPage(title: 'İlaç');
      case 3:
        return const _PlaceholderPage(title: 'Antidot');
      case 4:
      default:
        return const _PlaceholderPage(title: 'Hesap');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // Üst başlık + kırmızı "ACİL" pili
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'ACİL TIP ASİSTANI',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  const Spacer(),
                  // Kırmızı acil pili
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE25A5A), Color(0xFFD14848)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22E25A5A),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Text(
                      'ACİL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sekme butonları (pilli – görseldeki gibi)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = i == _index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _NavPill(
                        label: _tabs[i],
                        selected: selected,
                        onTap: () => setState(() => _index = i),
                        primary: primary,
                      ),
                    );
                  }),
                ),
              ),
            ),

            const Divider(height: 1),

            // İçerik
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildPage(_index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mavi seçili – açık gri seçilmemiş pilli düğme
class _NavPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  const _NavPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge!;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A3B5BDB),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  )
                ]
              : const [],
        ),
        child: Text(
          label,
          style: base.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// Sizin asıl sayfalarınız hazır olana kadar boş içerik
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title sayfası',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
