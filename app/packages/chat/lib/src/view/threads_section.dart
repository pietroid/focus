import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/threads_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a card is about to land: a list, and a place in it.
///
/// The index counts the list with the card being dragged already taken out of
/// it, which is the list the drop is going to be applied to.
typedef _Slot = ({ThreadBucket bucket, int index});

/// A place a card can land, and where it is on the screen.
typedef _Anchor = ({_Slot slot, double y});

/// A solved card on its way off the screen, frozen as it was let go.
typedef _Flying = ({
  ThreadSummary thread,
  double top,
  double height,
  double dx,
});

/// {@template threads_section}
/// The home screen's three lists: Agora, Em breve, and Depois.
///
/// One [Listener] over the whole thing owns every gesture: a tap opens a
/// thread, a press held for a moment picks its card up, and the card then
/// follows the finger while the rest of the lists open a place for it. The
/// place is whichever one is nearest, so the card lands wherever it is let
/// go rather than only on something it managed to hit.
///
/// A drag picks an axis as soon as it starts moving and keeps it. Up and down
/// reorders; left and right carries the card out of the timeline and solves
/// it. Nothing does both at once, because a card that slid sideways while
/// being reordered would be asking which of the two the finger meant, and the
/// finger has already said.
///
/// The lists do not re-lay-out while a card is up. The cards that move are
/// moved by a transform over a layout that was measured once, when the card
/// came up, so the place being aimed at cannot shift out from under the
/// finger that is aiming at it.
/// {@endtemplate}
class ThreadsSection extends StatefulWidget {
  /// {@macro threads_section}
  const ThreadsSection({required this.onThreadTap, super.key});

  /// Called with a thread's slug when its card is tapped.
  final ValueChanged<String> onThreadTap;

  @override
  State<ThreadsSection> createState() => _ThreadsSectionState();
}

class _ThreadsSectionState extends State<ThreadsSection> {
  /// How long a finger has to stay down before a card comes up with it.
  static const _holdDuration = Duration(milliseconds: 280);

  /// Moving further than this before the hold fires means the list is being
  /// scrolled, not a card picked up.
  static const _slop = 8.0;

  /// How far a card has to move before the drag picks its axis.
  static const _axisSlop = 12.0;

  /// How far sideways a card has to be carried before letting it go solves
  /// the thread rather than dropping it back into a list.
  static const _solveTravel = 96.0;

  /// The section itself, for turning the pointer into local coordinates.
  final GlobalKey _sectionKey = GlobalKey();

  /// One key per card, so the laid-out lists can be measured.
  final _cardKeys = <String, GlobalKey>{};

  /// One key per empty list, which is the only place such a list has.
  final _emptyKeys = <ThreadBucket, GlobalKey>{};

  Timer? _hold;
  Offset? _down;

  /// The card the finger is on, whether or not it has been picked up yet.
  String? _pressed;

  /// The card in the air.
  String? _dragging;

  /// Where the card came from, and what it measured, taken once at pick-up.
  Rect? _originRect;
  double _slotHeight = 0;

  /// The dragged card's place in the whole screen, counted in cards rather
  /// than in lists, because a card moving between lists moves everything
  /// under it: the headings below it as well as the cards.
  int _originPos = 0;

  /// How many cards come before each list, with and without the card in the
  /// air. Taken once at pick-up, from the layout the drag is measured in.
  final _before = <ThreadBucket, int>{};
  final _beforeWithout = <ThreadBucket, int>{};

  /// Every place the card could land, measured once at pick-up.
  List<_Anchor> _anchors = const [];

  /// The place it would land, and how far the finger has come since pick-up.
  _Slot? _target;
  Offset _travel = Offset.zero;

  /// Which way this drag is going, decided once and then kept.
  Axis? _axis;

  /// The card thrown off the timeline after being solved, still on screen
  /// while it plays out.
  _Flying? _flight;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  ThreadsState get _state => context.read<ThreadsBloc>().state;

  /// How far the card in the air has come towards being solved, 0 to 1.
  ///
  /// Always zero on a drag that went up or down, so a reorder never shows the
  /// check and never has to be read as anything but a reorder.
  double get _solveProgress {
    if (_dragging == null || _axis != Axis.horizontal) return 0;

    return (_travel.dx.abs() / _solveTravel).clamp(0.0, 1.0);
  }

  /// Whether letting go now would solve the thread instead of dropping it.
  bool get _armedSolve => _solveProgress == 1;

  GlobalKey _cardKey(String slug) => _cardKeys.putIfAbsent(slug, GlobalKey.new);

  GlobalKey _emptyKey(ThreadBucket bucket) =>
      _emptyKeys.putIfAbsent(bucket, GlobalKey.new);

  /// The global rect a key has been laid out into, if it is on screen.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The slug of the card under [global], if there is one.
  String? _cardAt(Offset global) {
    for (final entry in _cardKeys.entries) {
      if (_rectOf(entry.value)?.contains(global) ?? false) return entry.key;
    }

    return null;
  }

  /// Where [slug] sits right now.
  _Slot? _slotOf(String slug) {
    for (final bucket in ThreadBucket.values) {
      final index = _state.inBucket(bucket).indexWhere((t) => t.slug == slug);
      if (index != -1) return (bucket: bucket, index: index);
    }

    return null;
  }

  /// Measures every place [slug] could go, in the layout as it stands.
  ///
  /// A list of n cards has n + 1 places: above each card, and below the last.
  /// They are measured with [slug] taken out, because that is the list a drop
  /// is applied to, and from the resting layout, because the cards that move
  /// out of the way are moved by a transform and never change where they were
  /// laid out.
  List<_Anchor> _measure(String slug) {
    final anchors = <_Anchor>[];

    for (final bucket in ThreadBucket.values) {
      final rects = <Rect>[];
      for (final thread in _state.inBucket(bucket)) {
        if (thread.slug == slug) continue;
        final rect = _rectOf(_cardKey(thread.slug));
        if (rect != null) rects.add(rect);
      }

      if (rects.isEmpty) {
        // A list with nothing left in it has one place, on whatever it is
        // showing instead: its empty line, or the hole the card left.
        final rect = _rectOf(_emptyKey(bucket)) ?? _rectOf(_cardKey(slug));
        if (rect != null) {
          anchors.add((slot: (bucket: bucket, index: 0), y: rect.center.dy));
        }
        continue;
      }

      for (var index = 0; index < rects.length; index++) {
        anchors.add((
          slot: (bucket: bucket, index: index),
          y: rects[index].top,
        ));
      }
      anchors.add((
        slot: (bucket: bucket, index: rects.length),
        y: rects.last.bottom,
      ));
    }

    return anchors;
  }

  /// The place nearest [global], which is the one a drop lands on.
  _Slot? _nearest(Offset global) {
    if (_anchors.isEmpty) return null;

    return _anchors
        .reduce(
          (a, b) => (global.dy - a.y).abs() <= (global.dy - b.y).abs() ? a : b,
        )
        .slot;
  }

  /// How far the card with [before] cards above it on the whole screen has
  /// to move to open the place the card in the air is aiming at.
  ///
  /// One card leaves and one card arrives, and a card moves by however many
  /// of those two happened above it. Counting the screen rather than one list
  /// is what keeps the lists from running into each other: everything under
  /// the place the card is going moves down, and everything under the place
  /// it left moves up.
  double _shiftCard(int before) {
    final target = _target;
    if (target == null) return 0;

    final without = before - (_originPos < before ? 1 : 0);
    final insert = (_beforeWithout[target.bucket] ?? 0) + target.index;
    final to = without + (insert <= without ? 1 : 0);

    return (to - before) * _slotHeight;
  }

  /// How far [bucket]'s heading has to move.
  ///
  /// A heading is not a card but the line above one, so it cannot be worked
  /// out from a position the way a card can: the end of one list and the top
  /// of the next are the same place, and a heading sits between them. What
  /// moves it is which list the card came from and which it is going to, not
  /// where in them.
  double _shiftHeading(ThreadBucket bucket) {
    final target = _target;
    if (target == null) return 0;

    final before = _before[bucket] ?? 0;
    final left = _originPos < before ? -1 : 0;
    final arrived = target.bucket.index < bucket.index ? 1 : 0;

    return (left + arrived) * _slotHeight;
  }

  void _onDown(PointerDownEvent event) {
    _down = event.position;
    final slug = _cardAt(event.position);
    if (slug == null) return;

    setState(() => _pressed = slug);
    _hold = Timer(_holdDuration, () => _lift(slug));
  }

  void _lift(String slug) {
    final rect = _rectOf(_cardKey(slug));
    final origin = _slotOf(slug);
    if (rect == null || origin == null) return;

    var counted = 0;
    var countedWithout = 0;
    for (final bucket in ThreadBucket.values) {
      _before[bucket] = counted;
      _beforeWithout[bucket] = countedWithout;
      final threads = _state.inBucket(bucket);
      counted += threads.length;
      countedWithout += threads.where((t) => t.slug != slug).length;
    }

    setState(() {
      _dragging = slug;
      _axis = null;
      _originPos = (_before[origin.bucket] ?? 0) + origin.index;
      _originRect = rect;
      _slotHeight = rect.height + AppSpacing.s1;
      _anchors = _measure(slug);
      _travel = Offset.zero;
      _target = _nearest(_down!);
    });
  }

  void _onMove(PointerMoveEvent event) {
    final down = _down;
    if (down == null) return;

    if (_dragging != null) {
      final wasArmed = _armedSolve;
      final travel = event.position - down;

      setState(() {
        _axis = _axisFor(travel);
        // The card moves along the axis the drag chose and not a pixel along
        // the other one, so a reorder cannot drift sideways into solving the
        // thread and a card being carried out cannot drift into a list.
        _travel = _axis == Axis.horizontal
            ? Offset(travel.dx, 0)
            : Offset(0, travel.dy);
        // A card on its way out of the timeline is not aiming at a list, so
        // nothing opens a place for it: the lists stay where they are and the
        // only thing left to read is the check.
        _target = _axis == Axis.horizontal ? null : _nearest(event.position);
      });

      // One tick as the gesture changes what letting go will do, and only on
      // the change.
      if (_armedSolve != wasArmed) unawaited(HapticFeedback.selectionClick());
      return;
    }

    // Past the slop the gesture belongs to the list, which scrolls: the hold
    // is called off and the card under the finger stops looking pressed.
    if ((event.position - down).distance > _slop) _cancel();
  }

  /// The axis this drag is on: whichever way it went first, and then that one
  /// for the rest of the drag.
  ///
  /// Undecided counts as vertical, so the card is already following the finger
  /// up the list before the gesture has travelled far enough to be sure. A
  /// reorder is much the commoner of the two, and guessing it costs nothing
  /// when it is wrong: the first twelve pixels of a sideways drag simply do
  /// not move the card.
  Axis? _axisFor(Offset travel) {
    if (_axis != null || travel.distance < _axisSlop) return _axis;

    return travel.dx.abs() > travel.dy.abs() ? Axis.horizontal : Axis.vertical;
  }

  void _onUp(PointerUpEvent event) {
    final slug = _dragging;
    final target = _target;
    final pressed = _pressed;
    final solving = _armedSolve;
    final travel = _travel;
    final rect = _originRect;
    // A timer still ticking means the hold never fired, so this was a tap.
    final tapped = _hold?.isActive ?? false;
    final thread = slug == null ? null : _state.bySlug(slug);
    _cancel();

    if (slug == null) {
      if (tapped && pressed != null) widget.onThreadTap(pressed);
      return;
    }

    // Let go out to the side and the thread is solved: it leaves the timeline
    // for the concluded items, and the card is thrown after it.
    if (solving && thread != null && rect != null) {
      _solve(slug, thread, rect, travel);
      return;
    }

    if (target == null) return;

    // A card put back exactly where it came from is not a move, and does not
    // need to be written anywhere.
    final origin = _slotOf(slug);
    final from = origin?.bucket == target.bucket ? origin!.index : -1;
    if (from == target.index) return;

    context.read<ThreadsBloc>().add(
      ThreadMoved(slug: slug, bucket: target.bucket, index: target.index),
    );
  }

  /// Sends a thread to the concluded items, and throws its card off screen.
  ///
  /// This is the moment the thread is solved: everything before it was the
  /// gesture saying what it was about to do. The card is drawn from what was
  /// captured here rather than from the list, because the list has already
  /// let go of it by the time this runs, and everything below it closes up
  /// while the card is still on its way out.
  void _solve(String slug, ThreadSummary thread, Rect rect, Offset travel) {
    final box = _sectionKey.currentContext?.findRenderObject() as RenderBox?;
    unawaited(HapticFeedback.mediumImpact());

    if (box != null) {
      setState(() {
        _flight = (
          thread: thread,
          top: box.globalToLocal(rect.topLeft).dy + travel.dy,
          height: rect.height,
          dx: travel.dx,
        );
      });
    }

    context.read<ThreadsBloc>().add(ThreadSolved(slug, solved: true));
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
    _down = null;
    setState(() {
      _pressed = null;
      _dragging = null;
      _axis = null;
      _originRect = null;
      _anchors = const [];
      _target = null;
      _travel = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThreadsBloc, ThreadsState>(
      builder: (context, state) {
        if (state.isInitialLoad) return const _Loading();

        final dragging = _dragging;

        return Stack(
          key: _sectionKey,
          children: [
            Listener(
              // Translucent, so the list underneath still scrolls whenever
              // the gesture turns out not to be a drag.
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: (_) => _cancel(),
              // The list is frozen for as long as a card is up. The pointer
              // that picked the card up is one the scrollable is still
              // watching, and without this it would drag the list out from
              // under the place the card is aiming at.
              child: AbsorbPointer(
                absorbing: dragging != null,
                child: ListView(
                  physics: dragging == null
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    0,
                    AppSpacing.s6,
                    // Room under the last card so the bar never covers it.
                    AppSpacing.s16 + AppSpacing.s12,
                  ),
                  children: [
                    for (final bucket in ThreadBucket.values)
                      _Bucket(
                        bucket: bucket,
                        threads: state.inBucket(bucket),
                        pressed: _pressed,
                        dragging: dragging,
                        landing: _target?.bucket == bucket,
                        cardKey: _cardKey,
                        emptyKey: _emptyKey(bucket),
                        before: _before[bucket] ?? 0,
                        shiftCard: _shiftCard,
                        shiftHeading: _shiftHeading(bucket),
                      ),
                  ],
                ),
              ),
            ),
            // The card in the air is drawn over the lists rather than in
            // them, so it passes over the cards it is moving between instead
            // of sliding under them.
            if (dragging != null) _lifted(state, dragging),
            if (_flight != null) _flying(_flight!),
          ],
        );
      },
    );
  }

  Widget _lifted(ThreadsState state, String slug) {
    final rect = _originRect;
    final thread = state.bySlug(slug);
    final box = _sectionKey.currentContext?.findRenderObject() as RenderBox?;
    if (rect == null || thread == null || box == null) {
      return const SizedBox.shrink();
    }

    final top = box.globalToLocal(rect.topLeft).dy + _travel.dy;

    return Positioned(
      left: AppSpacing.s6,
      right: AppSpacing.s6,
      top: top,
      height: rect.height,
      child: IgnorePointer(
        child: _Lifted(
          thread: thread,
          dx: _travel.dx,
          progress: _solveProgress,
        ),
      ),
    );
  }

  /// The card that has just been solved, playing itself out.
  Widget _flying(_Flying flight) {
    return Positioned(
      left: AppSpacing.s6,
      right: AppSpacing.s6,
      top: flight.top,
      height: flight.height,
      child: IgnorePointer(
        child: _Flight(
          key: ValueKey(flight.thread.slug),
          thread: flight.thread,
          dx: flight.dx,
          onEnd: () {
            if (mounted) setState(() => _flight = null);
          },
        ),
      ),
    );
  }
}

/// The card in the air: the tile itself, and the check it is being carried
/// towards.
class _Lifted extends StatelessWidget {
  const _Lifted({
    required this.thread,
    required this.dx,
    required this.progress,
  });

  final ThreadSummary thread;

  /// How far sideways the finger has taken it.
  final double dx;

  /// How far along the way to being solved it is, 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The check sits in the room the card opened as it left, so it is
        // read beside the card rather than through it.
        Positioned.fill(
          child: Align(
            alignment: dx.isNegative
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: _SolveMark(progress: progress),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: ThreadTile(thread: thread, lifted: true),
          ),
        ),
      ],
    );
  }
}

/// The check beside a card being carried out of the timeline.
///
/// It fades up with the drag and goes from grey to white once the card has
/// gone far enough, so the gesture says what letting go will do before it
/// does it. It never turns green here: green is the thread being solved, and
/// that does not happen until the finger comes off.
class _SolveMark extends StatelessWidget {
  const _SolveMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final armed = progress == 1;

    return Opacity(
      opacity: 0.4 + 0.6 * progress,
      child: Transform.scale(
        scale: 0.8 + 0.2 * progress,
        child: AppIcon(
          iconData: AppIcons.check,
          color: armed ? AppColors.ink : AppColors.ink3,
        ),
      ),
    );
  }
}

/// The last quarter second of a solved card.
///
/// The card carries on the way it was going and fades out while the check
/// swells behind it. It is drawn over lists that have already closed the gap,
/// so by the time it is gone there is nothing left to tidy up.
class _Flight extends StatefulWidget {
  const _Flight({
    required this.thread,
    required this.dx,
    required this.onEnd,
    super.key,
  });

  final ThreadSummary thread;

  /// Where the card was when it was let go, and which way it was headed.
  final double dx;

  /// Called once there is nothing left to draw.
  final VoidCallback onEnd;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  /// How far past the release point the card carries on.
  static const _throw = 140.0;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  )..forward().whenComplete(widget.onEnd);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.dx.isNegative ? -1.0 : 1.0;

    return AnimatedBuilder(
      animation: _controller,
      child: ThreadTile(thread: widget.thread, lifted: true),
      builder: (context, child) {
        final t = Curves.easeIn.transform(_controller.value);

        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: sign.isNegative
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                  ),
                  child: Transform.scale(
                    scale: 1 + 0.5 * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: const AppIcon(
                        iconData: AppIcons.check,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(widget.dx + sign * _throw * t, 0),
                child: Opacity(
                  opacity: 1 - t,
                  child: Transform.scale(scale: 1 - 0.08 * t, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One list: its heading, and the cards in it.
class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.bucket,
    required this.threads,
    required this.pressed,
    required this.dragging,
    required this.landing,
    required this.cardKey,
    required this.emptyKey,
    required this.before,
    required this.shiftCard,
    required this.shiftHeading,
  });

  final ThreadBucket bucket;
  final List<ThreadSummary> threads;
  final String? pressed;
  final String? dragging;

  /// Whether the card in the air is currently aimed at this list.
  final bool landing;

  final GlobalKey Function(String slug) cardKey;
  final GlobalKey emptyKey;

  /// How many cards come before this list on the whole screen.
  final int before;

  /// How far a card with that many cards above it on the screen has to move.
  final double Function(int before) shiftCard;

  /// How far this list's heading, and its empty line, have to move.
  final double shiftHeading;

  /// Moves a row out of the way, but only while there is a card in the air.
  ///
  /// The wrapper goes when the drag does, rather than staying on to animate
  /// its way back to nothing: by then the lists have already been rebuilt in
  /// their new order, and animating the old offsets out on top of that is
  /// what made a dropped card drift after it had landed.
  Widget _row(double dy, Widget child) {
    if (dragging == null) return child;

    return _Slid(dy: dy, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      // Cards run the full width of the column. A card only as wide as its
      // title is a card with a dead right-hand side.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          shiftHeading,
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s6,
              bottom: AppSpacing.s2,
            ),
            child: Text(bucket.label, style: AppTypography.title),
          ),
        ),
        // A heading with nothing under it reads as a screen that failed to
        // load. One quiet line says the list is empty on purpose, and it is
        // also where a card lands when there is nothing to land beside.
        if (threads.isEmpty)
          _row(
            shiftHeading,
            _Empty(key: emptyKey, active: dragging != null && landing),
          ),
        for (var index = 0; index < threads.length; index++)
          _row(
            shiftCard(before + index),
            Padding(
              padding: EdgeInsets.only(top: index > 0 ? AppSpacing.s1 : 0),
              child: ThreadTile(
                key: cardKey(threads[index].slug),
                thread: threads[index],
                pressed: threads[index].slug == pressed,
                // The card in the air is drawn over the list, so the one
                // left behind only holds its place open.
                hidden: threads[index].slug == dragging,
              ),
            ),
          ),
      ],
    );
  }
}

/// A card moved out of the way, without being laid out anywhere else.
class _Slid extends StatelessWidget {
  const _Slid({required this.dy, required this.child});

  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: dy),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, value), child: child),
      child: child,
    );
  }
}

/// The line a list shows when there is nothing in it.
class _Empty extends StatelessWidget {
  const _Empty({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: active ? AppColors.fill : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        'Nada por aqui',
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Column(
        children: [
          AppSkeleton(height: AppSpacing.s16, radius: AppSpacing.chipRadius),
          SizedBox(height: AppSpacing.s1),
          AppSkeleton(height: AppSpacing.s16, radius: AppSpacing.chipRadius),
        ],
      ),
    );
  }
}
