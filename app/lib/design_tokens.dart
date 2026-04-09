import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class AtalaiaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double x2l = 32;
}

final class AtalaiaRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

final class AtalaiaElevation {
  static const double e0 = 0;
  static const double e1 = 1;
  static const double e2 = 2;
}

@immutable
final class AtalaiaBrandColors extends ThemeExtension<AtalaiaBrandColors> {
  const AtalaiaBrandColors({
    this.verifiedBlue = const Color(0xFF1D9BF0),
    this.success = const Color(0xFF2E7D32),
    this.warning = const Color(0xFFF9A825),
    this.error = const Color(0xFFC62828),
  });

  final Color verifiedBlue;
  final Color success;
  final Color warning;
  final Color error;

  @override
  AtalaiaBrandColors copyWith({
    Color? verifiedBlue,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AtalaiaBrandColors(
      verifiedBlue: verifiedBlue ?? this.verifiedBlue,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AtalaiaBrandColors lerp(ThemeExtension<AtalaiaBrandColors>? other, double t) {
    if (other is! AtalaiaBrandColors) return this;
    return AtalaiaBrandColors(
      verifiedBlue: Color.lerp(verifiedBlue, other.verifiedBlue, t) ?? verifiedBlue,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
    );
  }
}

extension AtalaiaContextX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  AtalaiaBrandColors get brand => Theme.of(this).extension<AtalaiaBrandColors>() ?? const AtalaiaBrandColors();
}

final class AtalaiaTapTarget {
  static const double min = 44;
}

final class AtalaiaText {
  static TextStyle h1(BuildContext context) {
    return (context.tt.titleLarge ?? const TextStyle()).copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: 0.1,
    );
  }

  static TextStyle h2(BuildContext context) {
    return (context.tt.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.18,
      letterSpacing: 0.1,
    );
  }

  static TextStyle body(BuildContext context) {
    return (context.tt.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
  }

  static TextStyle sub(BuildContext context) {
    return (context.tt.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
  }

  static TextStyle meta(BuildContext context) {
    return (context.tt.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: context.cs.onSurfaceVariant,
    );
  }
}

enum AtalaiaSnackKind { info, success, warning, error }

final atalaiaScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAtalaiaSnackBar(
  BuildContext context,
  String message, {
  AtalaiaSnackKind kind = AtalaiaSnackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  bool replaceCurrent = true,
}) {
  final ctx = atalaiaScaffoldMessengerKey.currentContext ?? context;
  final cs = Theme.of(ctx).colorScheme;
  final bg = switch (kind) {
    AtalaiaSnackKind.info => cs.inverseSurface,
    AtalaiaSnackKind.success => ctx.brand.success,
    AtalaiaSnackKind.warning => ctx.brand.warning,
    AtalaiaSnackKind.error => ctx.brand.error,
  };
  final fg = switch (kind) {
    AtalaiaSnackKind.info => cs.onInverseSurface,
    _ => Colors.white,
  };

  final snack = SnackBar(
    content: Text(message, style: TextStyle(color: fg)),
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(
            label: actionLabel,
            onPressed: onAction,
            textColor: fg,
          )
        : null,
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(milliseconds: 16), () {
      final messenger = atalaiaScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      if (replaceCurrent) messenger.removeCurrentSnackBar();
      messenger.showSnackBar(snack);
    });
  });
}

Future<bool?> showAtalaiaConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) {
  final resolvedCancelLabel = cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          AtalaiaTextButton(
            label: resolvedCancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          isDestructive
              ? DestructiveButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                )
              : PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
        ],
      );
    },
  );
}

Future<T?> showAtalaiaBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(AtalaiaTapTarget.min, AtalaiaTapTarget.min),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.lg)),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(AtalaiaTapTarget.min, AtalaiaTapTarget.min),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.lg)),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(AtalaiaTapTarget.min, AtalaiaTapTarget.min),
        backgroundColor: context.brand.error,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.lg)),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

class AtalaiaTextButton extends StatelessWidget {
  const AtalaiaTextButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(AtalaiaTapTarget.min, AtalaiaTapTarget.min),
        foregroundColor: isDestructive ? cs.error : null,
      ),
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}

class AtalaiaIconButton extends StatelessWidget {
  const AtalaiaIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          color: color,
          constraints: const BoxConstraints(
            minWidth: AtalaiaTapTarget.min,
            minHeight: AtalaiaTapTarget.min,
          ),
          padding: const EdgeInsets.all(10),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class AtalaiaFilledIconButton extends StatelessWidget {
  const AtalaiaFilledIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton.filled(
          onPressed: onPressed,
          constraints: const BoxConstraints(
            minWidth: AtalaiaTapTarget.min,
            minHeight: AtalaiaTapTarget.min,
          ),
          padding: const EdgeInsets.all(10),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class AtalaiaTextField extends StatelessWidget {
  const AtalaiaTextField({
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
        errorText: errorText,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.md)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtalaiaRadius.md),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtalaiaRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtalaiaRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtalaiaRadius.md),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    this.labelText,
    this.hintText = '',
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final resolvedHintText = hintText.isEmpty ? MaterialLocalizations.of(context).searchFieldLabel : hintText;
    return AtalaiaTextField(
      controller: controller,
      labelText: labelText,
      hintText: resolvedHintText,
      prefixIcon: Icons.search,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.labelText,
    this.hintText = '',
    this.showPasswordLabel = '',
    this.hidePasswordLabel = '',
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String hintText;
  final String showPasswordLabel;
  final String hidePasswordLabel;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AtalaiaTextField(
      controller: widget.controller,
      labelText: widget.labelText,
      hintText: widget.hintText,
      obscureText: _obscure,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      suffixIcon: AtalaiaIconButton(
        icon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        label: _obscure ? widget.showPasswordLabel : widget.hidePasswordLabel,
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

class MultiLineComposer extends StatelessWidget {
  const MultiLineComposer({
    required this.controller,
    required this.hintText,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    this.minLines = 3,
    this.maxLines = 6,
    this.sendOnEnter = false,
    this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final String? errorText;
  final bool enabled;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final bool sendOnEnter;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (!sendOnEnter || onSend == null) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
        if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
        onSend?.call();
        return KeyEventResult.handled;
      },
      child: AtalaiaTextField(
        controller: controller,
        hintText: hintText,
        errorText: errorText,
        enabled: enabled,
        focusNode: focusNode,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: sendOnEnter ? TextInputAction.send : TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        onSubmitted: sendOnEnter ? (_) => onSend?.call() : null,
      ),
    );
  }
}

class AtalaiaFilterChip extends StatelessWidget {
  const AtalaiaFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.pill)),
    );
  }
}

class VerifiedChip extends StatelessWidget {
  const VerifiedChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.pill)),
      avatar: Icon(Icons.verified, size: 16, color: context.brand.verifiedBlue),
      label: Text(label),
    );
  }
}

class PrivacyChip extends StatelessWidget {
  const PrivacyChip({
    required this.label,
    required this.icon,
    super.key,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.pill)),
      avatar: Icon(icon, size: 16, color: context.cs.onSurfaceVariant),
      label: Text(label),
    );
  }
}

class AtalaiaTagChip extends StatelessWidget {
  const AtalaiaTagChip({
    required this.label,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AtalaiaRadius.pill)),
      avatar: icon == null ? null : Icon(icon, size: 16, color: color ?? context.cs.onSurfaceVariant),
      label: Text(label),
    );
  }
}

enum AvatarSize { s24, s32, s44, s72, s96 }

class Avatar extends StatelessWidget {
  const Avatar({
    required this.name,
    this.imageUrl,
    this.size = AvatarSize.s44,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final AvatarSize size;

  double get _radius => switch (size) {
        AvatarSize.s24 => 12,
        AvatarSize.s32 => 16,
        AvatarSize.s44 => 22,
        AvatarSize.s72 => 36,
        AvatarSize.s96 => 48,
      };

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    final url = imageUrl?.trim();
    final hasNetworkImage = url != null &&
        url.isNotEmpty &&
        (url.startsWith('https://') || url.startsWith('http://'));
    return Semantics(
      image: true,
      label: name,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: _radius,
        backgroundImage: hasNetworkImage ? NetworkImage(url) : null,
        child: hasNetworkImage ? null : Text(letter),
      ),
    );
  }
}

class IconAvatar extends StatelessWidget {
  const IconAvatar({
    required this.icon,
    this.size = 44,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? cs.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foregroundColor ?? cs.onSurfaceVariant),
      ),
    );
  }
}

class Thumbnail extends StatelessWidget {
  const Thumbnail({this.size = 72, this.child, super.key});

  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AtalaiaRadius.md),
      child: Container(
        width: size,
        height: size,
        color: context.cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: child ?? Icon(Icons.image_outlined, color: context.cs.onSurfaceVariant),
      ),
    );
  }
}

class AtalaiaSkeletonBox extends StatelessWidget {
  const AtalaiaSkeletonBox({
    required this.width,
    required this.height,
    this.radius = 999,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AtalaiaRowSkeleton extends StatelessWidget {
  const AtalaiaRowSkeleton({
    this.avatarSize = 44,
    this.primaryWidth = 180,
    this.secondaryWidth = 240,
    super.key,
  });

  final double avatarSize;
  final double primaryWidth;
  final double secondaryWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AtalaiaSkeletonBox(width: avatarSize, height: avatarSize, radius: avatarSize / 2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AtalaiaSkeletonBox(width: primaryWidth, height: 12, radius: 6),
                const SizedBox(height: 8),
                AtalaiaSkeletonBox(width: secondaryWidth, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AtalaiaPostSkeleton extends StatelessWidget {
  const AtalaiaPostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AtalaiaSkeletonBox(width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AtalaiaSkeletonBox(width: 140, height: 12, radius: 6),
                      SizedBox(height: 8),
                      AtalaiaSkeletonBox(width: 100, height: 10, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AtalaiaSkeletonBox(width: double.infinity, height: 12, radius: 6),
            const SizedBox(height: 8),
            const AtalaiaSkeletonBox(width: 260, height: 12, radius: 6),
            const SizedBox(height: 12),
            const AtalaiaSkeletonBox(width: double.infinity, height: 240, radius: AtalaiaRadius.md),
          ],
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: AtalaiaElevation.e1,
      child: Padding(
        padding: const EdgeInsets.all(AtalaiaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: cs.onSurfaceVariant),
            const SizedBox(height: AtalaiaSpacing.md),
            Text(title, style: AtalaiaText.h2(context), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AtalaiaSpacing.sm),
              Text(subtitle!, style: AtalaiaText.sub(context), textAlign: TextAlign.center),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AtalaiaSpacing.lg),
              PrimaryButton(label: ctaLabel!, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}
