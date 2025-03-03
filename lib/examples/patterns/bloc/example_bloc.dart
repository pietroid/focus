import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'example_event.dart';
part 'example_state.dart';

class ExampleBloc extends Bloc<ExampleEvent, ExampleState> {
  ExampleBloc() : super(ExampleInitial()) {
    on<ExampleEventOne>((event, emit) {
      emit(ExampleStateA());
    });
    on<ExampleEventTwo>((event, emit) {
      emit(ExampleStateB());
    });
  }
}
