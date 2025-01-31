import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/common/data/domain_data.dart';
import 'package:focus/app/common/data/stream_cubit.dart';

class DataObserver<T> extends StatefulWidget {
  const DataObserver({
    required this.data,
    required this.builder,
    super.key,
  });
  final DomainData<T> data;
  final Widget Function(BuildContext context, List<T> data) builder;

  @override
  State<DataObserver<T>> createState() => _DataObserverState<T>();
}

class _DataObserverState<T> extends State<DataObserver<T>> {
  late StreamCubit<List<T>> streamCubit;

  @override
  void initState() {
    super.initState();
    streamCubit = StreamCubit<List<T>>(
      stream: widget.data.stream,
    );
  }

  @override
  void dispose() {
    streamCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreamCubit<List<T>>, List<T>>(
      bloc: streamCubit,
      builder: (context, state) => widget.builder(context, state),
    );
  }
}
