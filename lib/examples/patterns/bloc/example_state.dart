part of 'example_bloc.dart';

@immutable
sealed class ExampleState extends Equatable {}

class ExampleInitial extends ExampleState {
  @override
  List<Object> get props => [];
}

class ExampleStateA extends ExampleState {
  @override
  List<Object> get props => [];
}

class ExampleStateB extends ExampleState {
  @override
  List<Object> get props => [];
}
