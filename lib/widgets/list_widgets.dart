import 'package:flutter/material.dart';
import '../core/theme/palette.dart';
import 'app_alert.dart';

/// Small building blocks shared by the "More" list pages
/// (Categories, Locations, Purchase Orders, Users).

/// Search box with a clear (x) button.
class ListSearchField extends StatelessWidget {
  const ListSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

/// Port of components/common/ArchiveViewToggle.jsx.
class ArchiveViewToggle extends StatelessWidget {
  const ArchiveViewToggle({super.key, required this.archived, required this.onChanged});
  final bool archived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: false, label: Text('Active')),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.archive_outlined, size: 16),
          label: Text('Archived'),
        ),
      ],
      selected: {archived},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Loading skeleton / error / empty states for a pull-to-refresh list.
class ListStatus extends StatelessWidget {
  const ListStatus.loading({super.key, this.padding = _pad})
      : error = '',
        emptyIcon = null,
        emptyText = '',
        onRetry = null,
        _kind = 0;
  const ListStatus.error(this.error, {super.key, required this.onRetry, this.padding = _pad})
      : emptyIcon = null,
        emptyText = '',
        _kind = 1;
  const ListStatus.empty({super.key, required this.emptyIcon, required this.emptyText, this.padding = _pad})
      : error = '',
        onRetry = null,
        _kind = 2;

  static const _pad = EdgeInsets.fromLTRB(16, 8, 16, 96);

  final String error;
  final IconData? emptyIcon;
  final String emptyText;
  final VoidCallback? onRetry;
  final EdgeInsets padding;
  final int _kind;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (_kind == 0) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 70,
          decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    if (_kind == 1) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          AppAlert(error),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        const SizedBox(height: 56),
        Icon(emptyIcon, size: 40, color: p.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text(emptyText, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
      ],
    );
  }
}

/// One row of a list page: title, optional subtitle lines, trailing widget.
class ListRowCard extends StatelessWidget {
  const ListRowCard({
    super.key,
    required this.title,
    this.titleTrailing,
    this.lines = const [],
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final Widget? titleTrailing;
  final List<String> lines;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (titleTrailing != null) ...[const SizedBox(width: 8), titleTrailing!],
                      ],
                    ),
                    for (final line in lines)
                      if (line.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                        ),
                  ],
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded label (MUI `<Chip size="small">`), tone-colored.
class SmallChip extends StatelessWidget {
  const SmallChip(this.label, {super.key, this.color, this.outlined = false});
  final String label;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = color;
    final bg = outlined
        ? Colors.transparent
        : (c ?? (p.dark ? const Color(0xFF3A4F52) : const Color(0xFFE0E0E0)));
    final fg = outlined ? (c ?? p.textSecondary) : (c == null ? p.textPrimary : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: c ?? p.divider) : null,
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// Shows a floating message (the web's `<Snackbar>`).
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
