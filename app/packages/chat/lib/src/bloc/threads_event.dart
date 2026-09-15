part of 'threads_bloc.dart';

/// {@template threads_event}
/// Base class for events handled by [ThreadsBloc].
/// {@endtemplate}
sealed class ThreadsEvent extends Equatable {
  /// {@macro threads_event}
  const ThreadsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the thread list, or reloads it after the user returns to home.
final class ThreadsRequested extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadsRequested();
}
