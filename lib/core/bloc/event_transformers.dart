/// Shared Bloc event transformers.
library;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

/// Waits [duration] after the last event, then processes only the newest one.
///
/// Used for the search field. Restarting matters as much as the delay: if a
/// slow filter is still running when the user types again, its result is
/// discarded rather than racing the newer query and briefly rendering stale
/// results.
///
/// Built on `bloc_concurrency`'s [restartable] rather than `stream_transform`'s
/// `switchMap`. The two behave alike, but [restartable] is written against the
/// Bloc event lifecycle and handles handler cancellation itself, so it is the
/// right primitive here.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  final EventTransformer<E> switchToLatest = restartable<E>();

  // A zero-length debounce means "do not debounce": skip the wrapper rather
  // than arming a pointless zero-duration timer per event.
  if (duration <= Duration.zero) return switchToLatest;

  return (Stream<E> events, EventMapper<E> mapper) =>
      switchToLatest(events.debounce(duration), mapper);
}

/// Ignores events that arrive while one is already being handled.
///
/// This is the load-more guard. A fast flick emits several scroll-threshold
/// events; without this each would fire an identical request and triple the
/// spend against a 60/hour budget. Preferred over an `_isLoading` boolean
/// because the guard cannot be forgotten on an early return or a throw.
EventTransformer<E> dropWhileBusy<E>() => droppable<E>();
