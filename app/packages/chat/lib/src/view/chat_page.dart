import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/chat_bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

        final skeletonCount = state.isAwaitingReply ? 1 : 0;

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
                : AgentMessage(message: message);
          },
        );
      },
    );
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
