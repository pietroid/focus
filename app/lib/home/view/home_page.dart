import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';

/// {@template home_page}
/// Simple home page that greets the user and provides a single input.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          PopupMenuButton<void>(
            icon: const AppIcon(
              iconData: AppIcons.settings,
            ),
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: () {
                  context.read<AppBloc>().add(const AppLogoutRequested());
                },
                child: const Row(
                  children: [
                    AppIcon(
                      iconData: AppIcons.logout,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello ${firstName ?? 'there'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxlg),
              const _PromptField(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptField extends StatefulWidget {
  const _PromptField();

  @override
  State<_PromptField> createState() => _PromptFieldState();
}

class _PromptFieldState extends State<_PromptField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // TODO(pietro): wire up the prompt action.
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you want',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _controller,
          hintText: 'Type something...',
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          onPressed: _submit,
          text: 'Submit',
        ),
      ],
    );
  }
}
