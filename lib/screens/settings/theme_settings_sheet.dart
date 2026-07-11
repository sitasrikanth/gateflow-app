import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

Future<void> showThemeSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => const _ThemeSettingsSheet(),
  );
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  Widget _accentSwatch(BuildContext context, AppAccent accent, AppAccent current) {
    final swatch = accentSwatchFor(accent);
    final selected = accent == current;
    return GestureDetector(
      onTap: () async {
        final changed = accent != AppTheme.instance.accentKey;
        await AppTheme.instance.setAccent(accent);
        // Most screens read AppTheme.accent as a plain static value rather
        // than through Theme.of(context), so they won't rebuild on their
        // own when it changes. Reset back to Home so every screen is
        // rebuilt fresh with the new color.
        if (changed && context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: swatch,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.black87, width: 2.5)
                  : Border.all(color: Colors.grey.shade300),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(kAccentLabels[accent]!, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _modeChip(String label, IconData icon, ThemeMode value, ThemeMode current) {
    final selected = value == current;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: selected ? Colors.white : Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: selected,
      selectedColor: AppTheme.accent,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey.shade800),
      onSelected: (_) => AppTheme.instance.setMode(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 8),
                const Text('Theme',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ]),
              const SizedBox(height: 4),
              Text('Personal preference — only changes what you see on this device.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              Text('Accent color',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: AppAccent.values
                    .map((a) => _accentSwatch(context, a, AppTheme.instance.accentKey))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('Appearance',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _modeChip('Light', Icons.light_mode_outlined, ThemeMode.light, AppTheme.instance.mode),
                  _modeChip('Dark', Icons.dark_mode_outlined, ThemeMode.dark, AppTheme.instance.mode),
                  _modeChip('System', Icons.brightness_auto_outlined, ThemeMode.system, AppTheme.instance.mode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
