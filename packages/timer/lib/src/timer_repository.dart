class TimerRepository {
  Stream<DateTime> get currentTimeStream => Stream.periodic(
        const Duration(seconds: 1),
      ).map((event) => currentTime);

  DateTime get currentTime => DateTime.now();
}
