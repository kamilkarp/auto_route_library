import '../../utils.dart';
import 'resolved_type.dart';
import 'route_parameter_config.dart';

/// holds the extracted route configs
/// to be used in [RouterClassGenerator]
class RouteConfig {
  /// the route name
  final String? name;

  /// the path parameters of the route
  final List<PathParamConfig> pathParams;

  /// the page type of the route
  final ResolvedType? pageType;

  /// the class name of the route
  final String className;

  /// the return type of the route
  final ResolvedType? returnType;

  /// the parameters of the route
  final List<ParamConfig> parameters;

  /// whether the route has a wrapped route
  final bool? hasWrappedRoute;

  /// whether the route has a const constructor
  final bool hasConstConstructor;

  /// whether the route is deferred
  final bool? deferredLoading;

  final String source;

  final int hash;

  /// Default constructor
  RouteConfig({
    this.name,
    this.pathParams = const [],
    this.pageType,
    required this.className,
    this.parameters = const [],
    this.hasWrappedRoute,
    this.returnType,
    this.hasConstConstructor = false,
    this.deferredLoading,
    required this.hash,
    required this.source,
  });

  String get id => '$source@$className';

  /// The class name for ArgumentsHolder
  String get argumentsHolderClassName {
    return '${className}Arguments';
  }

  /// Returns all the non path/query params
  List<ParamConfig> get argParams {
    return parameters.where((p) => !p.isPathParam && !p.isQueryParam).toList();
  }

  /// Returns all the path/query params
  List<ParamConfig> get pathQueryParams {
    return parameters.where((p) => (p.isPathParam || p.isQueryParam)).toList();
  }

  /// Returns all the required params
  Iterable<ParamConfig> get requiredParams => parameters.where((p) => p.isPositional && !p.isOptional);

  /// Returns all the optional params
  Iterable<ParamConfig> get positionalParams => parameters.where((p) => p.isPositional);

  /// Returns all the named params
  Iterable<ParamConfig> get namedParams => parameters.where((p) => p.isNamed);

  /// Resolves the route name
  String getName([String? replacementInRouteName]) {
    var nameToUse;
    if (name != null) {
      nameToUse = name;
    } else if (replacementInRouteName != null && replacementInRouteName.split(',').length == 2) {
      var parts = replacementInRouteName.split(',');
      nameToUse = className.replaceAll(RegExp(parts[0]), parts[1]);
    } else {
      nameToUse = "${className}Route";
    }
    return capitalize(nameToUse);
  }

  /// Whether this route has arguments that can't be parsed
  bool get hasUnparsableRequiredArgs =>
      parameters.any((p) => (p.isRequired || p.isPositional) && !p.isPathParam && !p.isQueryParam);

  /// Clones the route config with the given parameters
  RouteConfig copyWith({
    String? name,
    String? pathName,
    List<PathParamConfig>? pathParams,
    bool? initial,
    bool? fullMatch,
    ResolvedType? pageType,
    String? className,
    ResolvedType? returnType,
    List<ParamConfig>? parameters,
    String? redirectTo,
    bool? hasWrappedRoute,
    String? replacementInRouteName,
    bool? hasConstConstructor,
    bool? deferredLoading,
    int? hash,
    String? source,
  }) {
    return RouteConfig(
      name: name ?? this.name,
      hash: hash ?? this.hash,
      source: source ?? this.source,
      pathParams: pathParams ?? this.pathParams,
      pageType: pageType ?? this.pageType,
      className: className ?? this.className,
      returnType: returnType ?? this.returnType,
      parameters: parameters ?? this.parameters,
      hasWrappedRoute: hasWrappedRoute ?? this.hasWrappedRoute,
      hasConstConstructor: hasConstConstructor ?? this.hasConstConstructor,
      deferredLoading: deferredLoading ?? this.deferredLoading,
    );
  }

  /// Serializes the route config to json
  Map<String, dynamic> toJson() {
    return {
      'name': this.name,
      'pathParams': this.pathParams.map((e) => e.toJson()).toList(),
      'pageType': this.pageType?.toJson(),
      'className': this.className,
      'returnType': this.returnType?.toJson(),
      'parameters': this.parameters.map((e) => e.toJson()).toList(),
      'hasWrappedRoute': this.hasWrappedRoute,
      'hasConstConstructor': this.hasConstConstructor,
      'deferredLoading': this.deferredLoading,
      'source': this.source,
      'hash': this.hash,
    };
  }

  /// Deserializes the route config from json
  factory RouteConfig.fromJson(Map<String, dynamic> map) {
    final pathParams = <PathParamConfig>[];
    if (map['pathParams'] != null) {
      for (final arg in map['pathParams']) {
        pathParams.add(PathParamConfig.fromJson(arg));
      }
    }

    final parameters = <ParamConfig>[];
    if (map['parameters'] != null) {
      for (final arg in map['parameters']) {
        parameters.add(ParamConfig.fromJson(arg));
      }
    }

    return RouteConfig(
      name: map['name'] as String?,
      pathParams: pathParams,
      hash: map['hash'] as int,
      pageType: map['pageType'] == null ? null : ResolvedType.fromJson(map['pageType']),
      className: map['className'] as String,
      returnType: map['returnType'] == null ? null : ResolvedType.fromJson(map['returnType']),
      parameters: parameters,
      hasWrappedRoute: map['hasWrappedRoute'] as bool?,
      hasConstConstructor: map['hasConstConstructor'] as bool,
      deferredLoading: map['deferredLoading'] as bool?,
      source: map['source'] as String,
    );
  }
}
