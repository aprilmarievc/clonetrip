import 'package:flutter/widgets.dart';

import 'services/firestore_service.dart';

class DataServiceScope extends InheritedWidget {
  const DataServiceScope({
    super.key,
    required this.service,
    required super.child,
  });

  final DataService service;

  static DataService of(BuildContext context) {
    final DataServiceScope? scope = context
        .dependOnInheritedWidgetOfExactType<DataServiceScope>();
    assert(scope != null, 'No DataServiceScope found in context');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(covariant DataServiceScope oldWidget) =>
      oldWidget.service != service;
}
