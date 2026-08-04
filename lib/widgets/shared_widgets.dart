// =============================================================================
// shared_widgets.dart
//
// Merged & refactored shared UI widget library.
//
// Sources integrated:
//   • Snippet 1 — original widget set (AnimatedContainer ModuleHeader, plain
//     SectionHeader, AppFormField with radiusSm / surface fill).
//   • Snippet 2 — card-shell ModuleHeader, accent-bar SectionHeader,
//     AppFormField with radiusMd / surfaceCard fill, InkWell ripple on action.
//
// Merge strategy:
//   • ModuleHeader  → Snippet 2 card shell (preferred for visual consistency).
//     Added `showCard` toggle so callers that previously relied on the bare
//     Snippet-1 layout can opt out.
//   • SectionHeader → Snippet 2 accent-bar + InkWell.
//   • AppFormField  → Snippet 2 border radius / fill; preserved all params.
//   • All other widgets are identical between snippets; one canonical version
//     kept, lightly documented.
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE HEADER
//
// Displays a large emoji icon alongside a title and subtitle.
//
// Integration notes:
//   • Snippet 1 wrapped content in a bare `AnimatedContainer` (no card).
//   • Snippet 2 wrapped content in a padded card with shadow + border.
//   • Combined: defaults to the card shell (Snippet 2). Set [showCard] = false
//     to replicate the Snippet-1 bare layout (e.g. inside an already-padded
//     parent card).
// ─────────────────────────────────────────────────────────────────────────────
class ModuleHeader extends StatelessWidget {
  /// Module display name shown in large bold text.
  final String title;

  /// Short description shown below [title].
  final String subtitle;

  /// Emoji character rendered inside the accent icon box.
  final String emoji;

  /// Accent colour applied to the icon box gradient and border.
  final Color color;

  /// When true (default), wraps the row in a rounded card with shadow.
  /// Set to false to render a bare row (Snippet-1 behaviour).
  final bool showCard;

  const ModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    this.showCard = true,
  });

  @override
  Widget build(BuildContext context) {
    // Animated entry on first build — retained from Snippet 1.
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Row(
        children: [
          // ── Emoji icon box ──────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),

          const SizedBox(width: AppTheme.spacingLg),

          // ── Title + subtitle ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Card shell — enabled by default (Snippet-2 behaviour).
    if (!showCard) return row;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: row,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
//
// A titled row with an optional action link.
//
// Integration notes:
//   • Snippet 1: plain `Text` label, `GestureDetector` action tap target.
//   • Snippet 2: adds a 4 × 18 px accent bar on the left edge and replaces
//     `GestureDetector` with `InkWell` for a native ripple effect.
//   • Combined: Snippet-2 layout is canonical; both are functionally identical
//     for callers since the public API is unchanged.
// ─────────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  /// Section label text.
  final String title;

  /// Optional label for the trailing action link. Requires [onAction].
  final String? actionText;

  /// Callback invoked when the action link is tapped.
  final VoidCallback? onAction;

  /// Accent bar colour. Defaults to [AppTheme.primary].
  final Color? accentColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = accentColor ?? AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      child: Row(
        children: [
          // ── Left accent bar (Snippet-2 addition) ────────────────
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(width: AppTheme.spacingSm),

          // ── Title ───────────────────────────────────────────────
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
          ),

          // ── Optional action link ─────────────────────────────────
          if (actionText != null)
            InkWell(
              // InkWell gives a native ripple (Snippet-2 improvement over
              // the plain GestureDetector used in Snippet 1).
              borderRadius: BorderRadius.circular(20),
              onTap: onAction,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  actionText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP FORM FIELD
//
// Styled TextFormField with label, optional prefix icon, and validator.
//
// Integration notes:
//   • Snippet 1: `radiusSm` border radius, `AppTheme.surface` fill colour.
//   • Snippet 2: `radiusMd` border radius, `AppTheme.surfaceCard` fill.
//   • Combined: Snippet-2 values are used (slightly larger radius + card fill
//     gives better visual consistency with other card-based widgets).
//     Added [onChanged] and [textCapitalization] that were absent from both.
// ─────────────────────────────────────────────────────────────────────────────
class AppFormField extends StatelessWidget {
  /// Floating label text.
  final String label;

  /// Ghost hint text shown when the field is empty.
  final String? hint;

  /// Optional prefix icon displayed inside the field.
  final IconData? icon;

  /// Keyboard type (e.g. number, email). Defaults to text.
  final TextInputType? keyboardType;

  /// When true the field is non-editable (read-only tap target).
  final bool readOnly;

  /// Number of lines. Use > 1 for multiline fields.
  final int maxLines;

  /// Controller for external read/write access to the field value.
  final TextEditingController? controller;

  /// Callback fired when the field is tapped (useful with [readOnly]).
  final VoidCallback? onTap;

  /// Validation function. Return an error string or null.
  final String? Function(String?)? validator;

  /// Callback fired on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Controls automatic capitalisation of typed text.
  final TextCapitalization textCapitalization;

  const AppFormField({
    super.key,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.controller,
    this.onTap,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onTap: onTap,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: AppTheme.textMuted)
            : null,
        filled: true,
        // Snippet-2 fill: surfaceCard (elevated white) rather than surface.
        fillColor: AppTheme.surfaceCard,
        border: OutlineInputBorder(
          // Snippet-2 radius: radiusMd for a softer, more card-consistent look.
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide:
              const BorderSide(color: AppTheme.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide:
              const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BUTTON
//
// Full-width elevated button with optional icon and loading state.
// Identical in both snippets; documented and lightly extended below.
// ─────────────────────────────────────────────────────────────────────────────
class SubmitButton extends StatelessWidget {
  /// Button label text.
  final String label;

  /// Tap callback. Pass null to disable the button (non-loading disabled state).
  final VoidCallback? onPressed;

  /// Background colour. Defaults to [AppTheme.primary].
  final Color color;

  /// When true, replaces label/icon with a white [CircularProgressIndicator]
  /// and disables the button.
  final bool isLoading;

  /// Optional leading icon displayed to the left of [label].
  final IconData? icon;

  const SubmitButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppTheme.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOD APPROVAL BADGE
//
// Compact inline badge indicating that HOD authorisation is needed.
// Identical in both snippets.
// ─────────────────────────────────────────────────────────────────────────────
class HodApprovalBadge extends StatelessWidget {
  /// Override text. Defaults to "HOD approval required".
  final String? text;

  const HodApprovalBadge({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: AppTheme.danger,
          ),
          const SizedBox(width: 6),
          Text(
            text ?? 'HOD approval required',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTE BOX
//
// Info / warning callout box with an icon, bold title, and body text.
// Identical in both snippets.
// ─────────────────────────────────────────────────────────────────────────────
class NoteBox extends StatelessWidget {
  /// Bold heading text.
  final String title;

  /// Descriptive body text beneath the title.
  final String content;

  /// Leading icon. Defaults to [Icons.info_outline].
  final IconData? icon;

  /// Accent colour for the icon, title, and border.
  /// Pass [AppTheme.warning] to switch to the warning background automatically.
  final Color? color;

  const NoteBox({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final boxColor = color ?? AppTheme.info;
    // Switch background based on the semantic colour provided.
    final bgColor =
        color == AppTheme.warning ? AppTheme.warningBg : AppTheme.infoBg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: boxColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, size: 18, color: boxColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: boxColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP CARD
//
// Numbered step container used inside multi-step forms.
// Identical in both snippets.
// ─────────────────────────────────────────────────────────────────────────────
class StepCard extends StatelessWidget {
  /// Ordinal step number displayed in the coloured badge.
  final int step;

  /// Step label shown next to the badge.
  final String title;

  /// Content widget rendered below the step header row.
  final Widget child;

  /// Badge colour. Defaults to [AppTheme.info].
  final Color? color;

  const StepCard({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final stepColor = color ?? AppTheme.info;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step number badge + title ────────────────────────────
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [stepColor, stepColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS CARD
//
// Small metric tile showing an icon, numeric value, and label.
// Identical in both snippets. Added [onTap] for drill-down navigation.
// ─────────────────────────────────────────────────────────────────────────────
class StatsCard extends StatelessWidget {
  /// Metric label rendered below the value.
  final String label;

  /// Formatted metric value (e.g. "42", "₹1.2L").
  final String value;

  /// Accent colour for the icon, value text, and gradient background.
  final Color color;

  /// Icon displayed above the value.
  final IconData icon;

  /// Optional tap callback for drill-down navigation.
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD
//
// Compact key-value display tile used in summary rows.
// Identical in both snippets.
// ─────────────────────────────────────────────────────────────────────────────
class InfoCard extends StatelessWidget {
  /// Field label rendered below the value in muted text.
  final String title;

  /// Field value rendered prominently.
  final String value;

  /// Optional leading icon.
  final IconData? icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.textMuted),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP WIDGET
//
// Toggle chip used in filter rows (e.g. date ranges, categories).
// Identical in both snippets.
// ─────────────────────────────────────────────────────────────────────────────
class FilterChipWidget extends StatelessWidget {
  /// Chip label text.
  final String label;

  /// Whether this chip is currently active / selected.
  final bool isSelected;

  /// Tap callback to toggle selection in the parent.
  final VoidCallback onTap;

  /// Fill + border colour when selected. Defaults to [AppTheme.primary].
  final Color? selectedColor;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 0 : 0.8,
          ),
          boxShadow: isSelected ? AppTheme.subtleShadow : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
//
// Selectable status pill used in status-selector rows.
// Identical in both snippets. Extracted icon logic into a helper for clarity.
// ─────────────────────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  /// Status label text (e.g. "Received", "Pending").
  final String label;

  /// Fill / border colour when selected.
  final Color color;

  /// Whether this badge is currently selected.
  final bool isSelected;

  /// Tap callback to select this badge in the parent.
  final VoidCallback onTap;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  /// Returns the appropriate icon for a given [label].
  /// Centralised here so the logic is easy to extend.
  IconData _iconFor(String label) {
    switch (label.toLowerCase()) {
      case 'received':
        return Icons.check_circle;
      case 'approved':
        return Icons.verified_rounded;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(_iconFor(label), size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING OVERLAY
//
// Overlays a semi-transparent scrim with a spinner when [isLoading] is true.
// Identical in both snippets. Added [message] for richer UX feedback.
// ─────────────────────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  /// Controls whether the overlay is visible.
  final bool isLoading;

  /// The widget rendered beneath the overlay.
  final Widget child;

  /// Optional message displayed below the spinner.
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Underlying content ──────────────────────────────────
        child,

        // ── Loading scrim + spinner ─────────────────────────────
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
                if (message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}