library;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

EventTransformer<E> debounceRestartable<E>(Duration duration) {
  final EventTransformer<E> switchToLatest = restartable<E>();

  if (duration <= Duration.zero) return switchToLatest;

  return (Stream<E> events, EventMapper<E> mapper) =>
      switchToLatest(events.debounce(duration), mapper);
}

EventTransformer<E> dropWhileBusy<E>() => droppable<E>();
