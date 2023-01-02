// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import '../../../api.dart' as api;
import '../common/attributes.dart';

class Resource {
  final Attributes _attributes;

  const Resource._(this._attributes);

  const Resource.empty() : 
  // ignore: invalid_constant
  _attributes = Attributes.empty();

  factory Resource(List<api.Attribute> attributes) {
    for (final attribute in attributes) {
      if (attribute.value is! String) {
        throw ArgumentError('Attributes value must be String.');
      }
    }
    final _attributes = Attributes.empty()..addAll(attributes);
    return Resource._(_attributes);
  }

  Attributes get attributes => _attributes;
}
