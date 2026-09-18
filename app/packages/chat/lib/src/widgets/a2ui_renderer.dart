import 'dart:developer';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template a2ui_renderer}
/// Renders an A2UI component tree using the existing app UI catalog.
///
/// Interactive components forward their actions to [onAction].
/// {@endtemplate}
class A2uiRenderer extends StatelessWidget {
  /// {@macro a2ui_renderer}
  const A2uiRenderer({
    required this.component,
    required this.onAction,
    this.enabled = true,
    super.key,
  });

  /// The root of the A2UI tree to render.
  final A2uiComponent component;

  /// Called when the user interacts with an actionable component.
  final void Function(Map<String, dynamic> action) onAction;

  /// Whether interactive components should respond to taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _buildComponent(context, component);
  }

  Widget _buildComponent(BuildContext context, A2uiComponent node) {
    return switch (node.component) {
      'Column' => _buildColumn(context, node),
      'Row' => _buildRow(context, node),
      'Spacer' => _buildSpacer(node),
      'Text' => _buildText(node),
      'Icon' => _buildIcon(node),
      'Image' => _buildImage(node),
      'AppButton' => _buildAppButton(node),
      'AppIconButton' => _buildAppIconButton(node),
      _ => _buildFallback(node),
    };
  }

  Widget _buildColumn(BuildContext context, A2uiComponent node) {
    final children = node.children ?? const [];

    return Column(
      mainAxisAlignment: _mainAxisAlignment(
        node.properties['mainAxisAlignment'],
      ),
      crossAxisAlignment: _crossAxisAlignment(
        node.properties['crossAxisAlignment'],
      ),
      children: children
          .map((child) => _buildComponent(context, child))
          .toList(),
    );
  }

  Widget _buildRow(BuildContext context, A2uiComponent node) {
    final children = node.children ?? const [];

    return Row(
      mainAxisAlignment: _mainAxisAlignment(
        node.properties['mainAxisAlignment'],
      ),
      crossAxisAlignment: _crossAxisAlignment(
        node.properties['crossAxisAlignment'],
      ),
      children: children
          .map((child) => _buildComponent(context, child))
          .toList(),
    );
  }

  Widget _buildSpacer(A2uiComponent node) {
    final width = _toDouble(node.properties['width']);
    final height = _toDouble(node.properties['height']);

    if (width == null && height == null) {
      return const Expanded(child: SizedBox.shrink());
    }

    return SizedBox(width: width, height: height);
  }

  Widget _buildText(A2uiComponent node) {
    final text = node.properties['text'] as String? ?? '';
    final variant = node.properties['variant'] as String? ?? 'body';

    return Text(
      text,
      style: _textStyleForVariant(variant),
    );
  }

  Widget _buildIcon(A2uiComponent node) {
    final iconName = node.properties['icon'] as String? ?? '';
    final size = _toDouble(node.properties['size']) ?? AppSpacing.iconSize;
    final color = _color(node.properties['color']);

    final iconData = _resolveIcon(iconName);
    if (iconData == null) {
      return Icon(Icons.help_outline, size: size, color: color);
    }

    return AppIcon(iconData: iconData, size: size, color: color);
  }

  Widget _buildImage(A2uiComponent node) {
    final src = node.properties['src'] as String? ?? '';
    final width = _toDouble(node.properties['width']);
    final height = _toDouble(node.properties['height']);
    final fit = _boxFit(node.properties['fit']);

    return Image.network(
      src,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
    );
  }

  Widget _buildAppButton(A2uiComponent node) {
    final text = node.properties['text'] as String? ?? '';
    final variant = node.properties['variant'] as String? ?? 'primary';
    final expand = node.properties['expand'] as bool? ?? false;
    final action = node.action;

    return AppButton(
      onPressed: enabled && action != null
          ? () {
              log(
                '[A2uiRenderer] AppButton pressed',
                name: 'a2ui_renderer',
                error: {'text': text, 'action': action},
              );
              onAction(action);
            }
          : null,
      text: text,
      variant: _buttonVariant(variant),
      expand: expand,
    );
  }

  Widget _buildAppIconButton(A2uiComponent node) {
    final iconName = node.properties['icon'] as String? ?? '';
    final size = _toDouble(node.properties['size']) ?? AppSpacing.iconSize;
    final color = _color(node.properties['color']);
    final action = node.action;
    final iconData = _resolveIcon(iconName);

    return AppIconButton(
      iconData: iconData ?? AppIcons.settings,
      onPressed: enabled && action != null
          ? () {
              log(
                '[A2uiRenderer] AppIconButton pressed',
                name: 'a2ui_renderer',
                error: {'icon': iconName, 'action': action},
              );
              onAction(action);
            }
          : () {},
      size: size,
      color: color,
    );
  }

  Widget _buildFallback(A2uiComponent node) {
    return Text(
      'Unsupported component: ${node.component}',
      style: AppTypography.bodyRegular.copyWith(color: AppColors.negative),
    );
  }

  AppIconData? _resolveIcon(String name) {
    return switch (name) {
      'check' => const AppIconData.phosphor(Icons.check),
      'send' => AppIcons.send,
      'pen' => AppIcons.pen,
      'home' => AppIcons.home,
      'settings' => AppIcons.settings,
      'logout' => AppIcons.logout,
      'back' => AppIcons.back,
      'chevronRight' => AppIcons.chevronRight,
      'more' => const AppIconData.phosphor(Icons.more_horiz),
      'close' => const AppIconData.phosphor(Icons.close),
      _ => null,
    };
  }

  TextStyle _textStyleForVariant(String variant) {
    return switch (variant) {
      'headline' => AppTypography.headline,
      'title' => AppTypography.title,
      'caption' => AppTypography.caption,
      'label' => AppTypography.label,
      _ => AppTypography.bodyRegular,
    };
  }

  AppButtonVariant _buttonVariant(String variant) {
    return switch (variant) {
      'secondary' => AppButtonVariant.secondary,
      'text' => AppButtonVariant.text,
      _ => AppButtonVariant.primary,
    };
  }

  MainAxisAlignment _mainAxisAlignment(Object? value) {
    return switch (value) {
      'end' => MainAxisAlignment.end,
      'center' => MainAxisAlignment.center,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
  }

  CrossAxisAlignment _crossAxisAlignment(Object? value) {
    return switch (value) {
      'end' => CrossAxisAlignment.end,
      'center' => CrossAxisAlignment.center,
      'stretch' => CrossAxisAlignment.stretch,
      _ => CrossAxisAlignment.start,
    };
  }

  BoxFit _boxFit(Object? value) {
    return switch (value) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'none' => BoxFit.none,
      _ => BoxFit.cover,
    };
  }

  Color? _color(Object? value) {
    return switch (value) {
      'accent' => AppColors.accent,
      'ink' => AppColors.ink,
      'ink2' => AppColors.ink2,
      'ink3' => AppColors.ink3,
      'error' => AppColors.negative,
      _ => null,
    };
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
