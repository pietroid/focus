import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'example_state.dart';

class ExampleCubit extends Cubit<ExampleState> {
  ExampleCubit() : super(ExampleInitial());

  void methodOne() {
    emit(ExampleStateA());
  }

  void methodTwo() {
    emit(ExampleStateB());
  }
}
