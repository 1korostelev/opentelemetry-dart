// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

import '../../../../api.dart' as api;

class BatchSpanProcessor implements api.SpanProcessor {
  final _log = Logger('opentelemetry.BatchSpanProcessor');

  final api.SpanExporter _exporter;
  bool _isShutdown = false;
  final List<api.Span> _spanBuffer = [];
  Timer? _timer;

  final int maxExportBatchSize;
  final int _maxQueueSize = 2048;
  final int scheduledDelayMillis;

  BatchSpanProcessor(
    this._exporter, {
    this.maxExportBatchSize = 512,
    this.scheduledDelayMillis = 5000,
  });

  @override
  void forceFlush() {
    if (_isShutdown) {
      return;
    }
    while (_spanBuffer.isNotEmpty) {
      _flushBatch();
    }
    _exporter.forceFlush();
  }

  @override
  void onEnd(api.Span span) {
    if (_isShutdown) {
      return;
    }
    _addToBuffer(span);
  }

  @override
  void onStart(api.Span span, api.Context parentContext) {}

  @override
  void shutdown() {
    forceFlush();
    _isShutdown = true;
    _clearTimer();
    _exporter.shutdown();
  }

  void _addToBuffer(api.Span span) {
    if (_spanBuffer.length >= _maxQueueSize) {
      // Buffer is full, drop span.
      _log.warning(
          'Max queue size exceeded. Dropping ${_spanBuffer.length} spans.');
      return;
    }

    _spanBuffer.add(span);
    _startTimer();
  }

  void _startTimer() {
    if (_timer != null) {
      // _timer already defined.
      return;
    }

    _timer = Timer(Duration(milliseconds: scheduledDelayMillis), () {
      _flushBatch();
      if (_spanBuffer.isNotEmpty) {
        _clearTimer();
        _startTimer();
      }
    });
  }

  void _clearTimer() {
    if (_timer == null) {
      // _timer not set.
      return;
    }

    _timer!.cancel();
    _timer = null;
  }

  void _flushBatch() {
    _clearTimer();
    if (_spanBuffer.isEmpty) {
      return;
    }

    final batchSize = min(_spanBuffer.length, maxExportBatchSize);
    final batch = _spanBuffer.sublist(0, batchSize);
    _spanBuffer.removeRange(0, batchSize);

    _exporter.export(batch);
  }
}
