import 'package:app_ui/app_ui.dart';

/// Extension on [BuildContext] for easy access to custom theme tokens.
extension AppThemeBuildContext on BuildContext {
  /// Returns the [AppTextStyles] from the current theme.
  AppTextStyles get appTextStyles => Theme.of(this).extension<AppTextStyles>()!;
}
