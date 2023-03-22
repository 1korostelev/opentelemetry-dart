import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../../../api.dart' as api;
import '../../../../sdk.dart' as sdk;
import 'dart:convert' as convert;

class JaegerExporter implements api.SpanExporter {
  Uri uri;
  late final http.Client client;
  var _isShutdown = false;

  JaegerExporter(this.uri, {http.Client? httpClient}) {
    client = httpClient ?? http.Client();
  }

  @override
  void export(List<api.Span> spans) {
    if (_isShutdown) {
      return;
    }

    if (spans.isEmpty) {
      return;
    }

    final spansList = spansToMap(spans);
    Logger().i({
      'data': spansList,
      'converted': convert.jsonEncode(spansList),
    });

    // client.post(
    //   uri,
    //   body: convert.jsonEncode(spansList),
    //   headers: {
    //     'Content-Type': 'application/json',
    //   },
    // );
  }

  List<Map<String, dynamic>> spansToMap(List<api.Span> spans) {
    final items = <Map<String, dynamic>>[];
    try {
      for (final span in spans) {
        final fields = <String, dynamic>{
          'traceId': '${span.spanContext.traceId}',
          'name': span.name,
          'id': '${span.spanContext.spanId}',
          'timestamp': span.startTime?.toInt(),
          'duration': (span.endTime! - span.startTime!).toInt(),
          'localEndpoint': {'serviceName': 'app'},
          'tags': <String, dynamic>{
            'service.name': 'app',
            'telemetry.sdk.language': 'dart',
            'telemetry.sdk.name': 'opentelemetry',
            'telemetry.sdk.version': '1.9.1'
          },
        };
        final attributes = extractSpanAttributes(span);
        Logger().i(attributes);
        (fields['tags'] as Map).addAll(attributes);

        items.add(fields);
      }
    } catch (e) {
      Logger().e(e);
      return items;
    }
    return items;
  }

  Map<String, dynamic> extractSpanAttributes(api.Span span) {
    final attributes = <String, dynamic>{};
    try {
      final attrs = (span as sdk.Span).attributes;
      for (final element in attrs.keys) {
        attributes.putIfAbsent(
          element,
          () => attrs.get(element),
        );
      }
    } catch (e) {
      Logger().e(e);
    }

    return attributes;
  }

  @override
  void forceFlush() {
    return;
  }

  @override
  void shutdown() {
    _isShutdown = true;
    client.close();
  }
}
