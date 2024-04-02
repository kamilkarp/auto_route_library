import 'dart:convert';
import 'dart:io';

import 'package:auto_route_generator/src/models/route_config.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

const _cachePath = '.dart_tool/auto_route/routes_config.json';
final _cacheFile = File(p.join(Directory.current.path, _cachePath));

class RoutesTracker {
  int generatedTimeStamp;
  final List<RouteConfig> routes;
  bool hasChanges;

  RoutesTracker({
    required this.generatedTimeStamp,
    required this.routes,
    this.hasChanges = false,
  });

  RouteConfig? routeByPath(String source) {
    return routes.firstWhereOrNull((e) => e.source == source);
  }

  bool shouldUpdate(File source) {
    final route = routeByPath(source.path);
    if (route == null) {
      return true;
    }
    return source.lastModifiedSync().millisecondsSinceEpoch > generatedTimeStamp;
  }

  RouteConfig? routeByIdentity(String source, String className) {
    return routes.firstWhereOrNull((e) => e.id == '$source@$className');
  }


  Map<String, dynamic> toJson() {
    return {
      'generatedTimeStamp': this.generatedTimeStamp,
      'routes': this.routes.map((e) => e.toJson()).toList(),
    };
  }

  void removeBySource(String source) {
    for (var i = 0; i < routes.length; i++) {
      if (routes[i].source == source) {
        routes.removeAt(i);
        hasChanges = true;
        break;
      }
    }
  }

  void upsert(RouteConfig route) {
    hasChanges = true;
    final index = routes.indexWhere((e) => e.id == route.id);
    if (index != -1) {
      routes[index] = route;
    } else {
      routes.add(route);
    }
    ;
  }

  Future<void> presist() async {
    if (!_cacheFile.existsSync()) {
      _cacheFile.createSync(recursive: true);
    }
    hasChanges = false;
    generatedTimeStamp = DateTime.timestamp().millisecondsSinceEpoch;
    return _cacheFile.writeAsStringSync(
      jsonEncode(this.toJson()),
    );
  }

  static RoutesTracker load(Set<String> assets) {
    if (!_cacheFile.existsSync())
      return RoutesTracker(
        generatedTimeStamp: 0,
        routes: [],
      );
    final json = jsonDecode(_cacheFile.readAsStringSync());
    final routes = <RouteConfig>[];
    bool hasChanges = false;
    for (var i = 0; i < json['routes'].length; i++) {
      final route = RouteConfig.fromJson(json['routes'][i]);
      if (assets.contains(route.source)) {
        routes.add(route);
      } else {
        hasChanges = true;
      }
    }
    return RoutesTracker(
      generatedTimeStamp: json['generatedTimeStamp'] as int,
      routes: routes,
      hasChanges: hasChanges,
    );
  }
}
