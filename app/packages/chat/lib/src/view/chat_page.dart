import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/chat_bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// {@template chat_page}
/// One conversation.
///
/// Reached two ways: opening a thread from the home list, which loads it by
/// slug, or typing the first message on the home screen, which arrives as
/// [initialMessage] and creates the thread here so the send and its loading
/// state happen on the screen that shows them.
/// {@endtemplate}
class ChatPage extends StatelessWidget {
  /// {@macro chat_page}
  const ChatPage({this.slug, this.initialMessage, super.key});

  /// The thread to open. Null when the user is starting a new one.
  final String? slug;

  /// The message that started a new thread, sent as soon as the page opens.
  final String? initialMessage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = ChatBloc(
          chatRepository: context.read<ChatRepository>(),
        );

        if (initialMessage != null) {
          bloc.add(ChatMessageSent(initialMessage!));
        } else if (slug != null) {
          bloc.add(ChatThreadRequested(slug!));
        }

        return bloc;
      },
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      child: BlocListener<ChatBloc, ChatState>(
        listenWhen: (previous, current) =>
            previous.pendingToolCall != current.pendingToolCall &&
            current.pendingToolCall != null,
        listener: (context, state) {
          unawaited(_showToolConfirmation(context, state.pendingToolCall!));
        },
        child: Scaffold(
          appBar: AppBar(
            leading: AppIconButton(
              iconData: AppIcons.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: BlocBuilder<ChatBloc, ChatState>(
              buildWhen: (previous, current) => previous.title != current.title,
              builder: (context, state) => Text(
                state.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: const Column(
                  children: [
                    Expanded(child: _Messages()),
                    _Composer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showToolConfirmation(
    BuildContext context,
    PendingToolCall pending,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Confirm action',
          style: AppTypography.title,
        ),
        content: Text(
          'Allow ${pending.name}?',
          style: AppTypography.bodyRegular,
        ),
        actions: [
          AppButton.text(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            text: 'Cancel',
          ),
          AppButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            text: 'Confirm',
          ),
        ],
      ),
    );

    if (confirmed == null) {
      if (!context.mounted) return;
      context.read<ChatBloc>().add(const ChatA2uiAction({'type': 'dismiss'}));
      return;
    }

    if (!context.mounted) return;
    context.read<ChatBloc>().add(
          ChatToolConfirmed(
            toolCallId: pending.id,
            confirmed: confirmed,
          ),
        );
  }
}

class _Messages extends StatelessWidget {
  const _Messages();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state.status == ChatStatus.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s4,
            ),
            child: AgentMessageSkeleton(),
          );
        }

        final skeletonCount = state.isAwaiting ? 1 : 0;
        final actionsEnabled = !state.isAwaitingAction;

        // Reversed so the list sits at the newest message without measuring
        // anything, and so new messages push up from the composer rather than
        // needing a scroll animation to be seen.
        return ListView.separated(
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s4,
          ),
          itemCount: state.messages.length + skeletonCount,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s4),
          itemBuilder: (context, index) {
            if (index < skeletonCount) return const AgentMessageSkeleton();

            final message = state
                .messages[state.messages.length - 1 - index + skeletonCount];

            return message.isUser
                ? ChatBubble(message: message)
                : AgentMessage(
                    message: message,
                    enabled: actionsEnabled,
                    onAction: (action) => _handleAction(context, action),
                  );
          },
        );
      },
    );
  }

  void _handleAction(BuildContext context, Map<String, dynamic> action) {
    final type = action['type'] as String?;

    if (type == 'openUrl') {
      final url = action['url'] as String?;
      if (url != null && url.isNotEmpty) {
        unawaited(_launchUrl(url));
      }
      return;
    }

    context.read<ChatBloc>().add(ChatA2uiAction(action));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s2,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: ChatComposer(
        hintText: 'Escreva uma mensagem',
        onSubmitted: (text) =>
            context.read<ChatBloc>().add(ChatMessageSent(text)),
      ),
    );
  }
}

/// Helper to silence the "unawaited future" lint for fire-and-forget calls.
void unawaited(Future<void> future) {}
