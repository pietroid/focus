part of 'example_bloc.dart';

@immutable
sealed class ExampleEvent {}

class ExampleEventOne extends ExampleEvent {}

class ExampleEventTwo extends ExampleEvent {}
