import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.trailing,
    this.previousPageTitle,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final String? previousPageTitle;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = Navigator.of(context).canPop();
    final resolvedLeading =
        leading ??
        (automaticallyImplyLeading && canPop
            ? AppNavIconButton(
                icon: CupertinoIcons.chevron_left,
                semanticLabel: l10n.ui('返回'),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppPalette.surface.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: AppPalette.border.withValues(alpha: 0.7)),
        ),
        automaticallyImplyLeading: false,
        leading: resolvedLeading,
        middle: title.isEmpty ? null : Text(l10n.ui(title)),
        trailing: trailing,
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class AppNavIconButton extends StatelessWidget {
  const AppNavIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppPalette.brand,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        label: l10n.ui(semanticLabel),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppPalette.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F1915),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 21),
        ),
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.85)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1915),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null
              ? AppPalette.brand.withValues(alpha: 0.28)
              : AppPalette.brand,
          borderRadius: BorderRadius.circular(9),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppPalette.brand.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Center(
            child: Text(
              l10n.ui(label),
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppPalette.brand.withValues(alpha: 0.72)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Text(
                l10n.ui(label),
                style: const TextStyle(
                  color: AppPalette.brand,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.placeholder,
    this.controller,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
  });

  final String placeholder;
  final TextEditingController? controller;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoTextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      placeholder: l10n.ui(placeholder),
      placeholderStyle: const TextStyle(color: AppPalette.mutedText),
      prefix: prefix == null
          ? null
          : Padding(padding: const EdgeInsets.only(left: 14), child: prefix),
      suffix: suffix == null
          ? null
          : Padding(padding: const EdgeInsets.only(right: 10), child: suffix),
      style: const TextStyle(color: AppPalette.strongText, fontSize: 16),
      decoration: BoxDecoration(
        color: AppPalette.surfaceWarm,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.72)),
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ui(title),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppPalette.strongText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.ui(subtitle),
          style: const TextStyle(
            fontSize: 14,
            color: AppPalette.mutedText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? AppPalette.brandLight : AppPalette.surfaceWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? AppPalette.brand.withValues(alpha: 0.18)
                : AppPalette.border.withValues(alpha: 0.75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ui(label),
              style: const TextStyle(color: AppPalette.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.ui(value),
              style: TextStyle(
                color: highlight ? AppPalette.brandDark : AppPalette.strongText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ui(caption),
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppPalette.brandLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppPalette.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ui(title),
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.ui(subtitle),
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(
                CupertinoIcons.chevron_forward,
                color: AppPalette.mutedText,
                size: 18,
              ),
        ],
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppPalette.background,
            AppPalette.backgroundCool,
            AppPalette.background,
          ],
        ),
      ),
      child: child,
    );
  }
}

class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.icon,
    this.color = AppPalette.brandLight,
    this.textColor = AppPalette.brandDark,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            l10n.ui(label),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppPalette.brandLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.brand.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.brand.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTag(
            label: badge,
            icon: CupertinoIcons.sparkles,
            color: AppPalette.surface,
            textColor: AppPalette.brandDark,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ui(title),
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.ui(subtitle),
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ],
      ),
    );
  }
}

class AppProductTile extends StatelessWidget {
  const AppProductTile({
    super.key,
    required this.icon,
    required this.title,
    required this.price,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppPalette.brandDark, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.strongText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            price,
            style: const TextStyle(
              color: AppPalette.brand,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AppQuickAction extends StatelessWidget {
  const AppQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppPalette.brandDark, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                l10n.ui(label),
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
