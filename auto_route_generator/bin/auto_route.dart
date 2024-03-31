import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:auto_route_generator/src/code_builder/library_builder.dart';
import 'package:auto_route_generator/src/models/resolved_type.dart';
import 'package:auto_route_generator/src/models/route_config.dart';
import 'package:auto_route_generator/src/models/router_config.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'ast_extensions.dart';
import 'resolvers/ast_parameter_resolver.dart';
import 'resolvers/ast_type_resolver.dart';
import 'resolvers/package_file_resolver.dart';
import 'sdt_out_utils.dart';
import 'sequence_matcher/sequence.dart';
import 'sequence_matcher/sequence_matcher.dart';
import 'sequence_matcher/utils.dart';
import 'utils.dart';

final _configFile = File('auto_route_config.txt');
late final rootPackage = rootPackageName;

void main() async {
  printBlue('AutoRoute Builder Started...');
  final stopWatch = Stopwatch()..start();
  final root = Directory.current.uri;
  // final root = Uri.parse('/Users/milad/AndroidStudioProjects/$rootPackage');
  late final fileResolver = PackageFileResolver.forRoot(root.path);
  late final matcher = SequenceMatcher(fileResolver);
  final lastGenerate = _configFile.existsSync() ? int.parse(_configFile.readAsStringSync()) : 0;
  final glob = Glob('**screen.dart');
  final libDir = Directory.fromUri(Uri.parse(p.join(root.path, 'lib')));
  final assets = glob.listSync(root: libDir.path, followLinks: true).whereType<File>();
  printYellow('Assets collected in ${stopWatch.elapsedMilliseconds}ms');
  final stopWatch2 = Stopwatch()..start();

  final routesResult = await Future.wait([
    for (final asset in assets) _processFile(asset, () => matcher, lastGenerate),
  ]);
  // final port = ReceivePort();
  // await Isolate.spawn((message) { }, port.sendPort);
  // port.toList();

  //
  // final routesResult = <RouteConfig?>[];
  // for (final asset in assets) {
  //   final result = await _processFile(asset, () => matcher, lastGenerate);
  //   routesResult.add(result);
  // }
  printYellow('Processing took ${stopWatch2.elapsedMilliseconds}ms');

  final routes = routesResult.whereNotNull();
  if (routes.isNotEmpty) {
    final RouterConfig config = RouterConfig(
      routerClassName: 'AstRouterTest',
      path: '/lib/router.dart',
      cacheHash: 0,
      generateForDir: ['lib'],
    );
    File('router.dart').writeAsStringSync(generateLibrary(config, routes: routes.toList()));
  }
  printGreen('Build finished in: ${stopWatch.elapsedMilliseconds}ms');

  _configFile.writeAsStringSync((DateTime.timestamp().millisecondsSinceEpoch).toString());
  stopWatch.stop();
  // printYellow('Watching for changes inside: lib | ${glob.pattern}');
  // libDir.watch(events: FileSystemEvent.all, recursive: true).listen((event) async {
  //   if (glob.matches(event.path)) {
  //     final stopWatch = Stopwatch()..start();
  //     final asset = File(event.path);
  //     await _processFile(asset, () => matcher, lastGenerate);
  //     printGreen('Watched file took: ${stopWatch.elapsedMilliseconds}ms');
  //     _configFile.writeAsStringSync((DateTime.timestamp().millisecondsSinceEpoch).toString());
  //   }
  // });
}

Future<RouteConfig?> _processFile(File asset, SequenceMatcher Function() matcher, int lastGenerate) async {
  // if (asset.lastModifiedSync().millisecondsSinceEpoch < lastGenerate) return null;
  final bytes = await asset.readAsBytes();
  if (!hasRouteAnnotation(bytes)) return null;

  final assetContent = utf8.decode(bytes);
  final unit = parseString(content: assetContent, throwIfDiagnostics: false).unit;
  final classDeclarations = unit.declarations.whereType<ClassDeclaration>();
  final routePage = classDeclarations.firstWhereOrNull((e) => e.hasRoutePageAnnotation);
  if (routePage == null || !routePage.hasDefaultConstructor) return null;
  final annotation = routePage.routePageAnnotation;
  final className = routePage.name.lexeme;
  printBlue('Processing: ${className}');

  late final imports = unit.directives
      .whereType<ImportDirective>()
      .where((e) => e.uri.stringValue != null)
      .map((e) => Uri.parse(e.uri.stringValue!))
      .sortedBy<num>((e) {
    final package = e.pathSegments.first;
    if (package == 'flutter') return 1;
    return !e.hasScheme || package == rootPackage ? -1 : 0;
  }).toList();

  final params = routePage.defaultConstructorParams;

  final identifiersToLookUp = {
    ...annotation.returnIdentifiers,
    for (final param in params) ...?param.type?.identifiers,
  }.whereNot(dartCoreTypeNames.contains);

  final resolvedLibs = {
    asset.uri.path: {for (final declaration in unit.declarations) declaration.name},
  };
  final stopWatch = Stopwatch()..start();

  if (identifiersToLookUp.isNotEmpty) {
    final resolved = matcher().resolvedIdentifiers;
    final result = await matcher().locateTopLevelDeclarations(
      asset.uri,
      imports,
      [
        for (final type in identifiersToLookUp) ...[
          Sequence(type, 'class ${type}', terminators: [32, 0x3C]),
          Sequence(type, 'typedef ${type}', terminators: [32, 0x3C]),
        ],
      ],
    );
    if (result.isNotEmpty) {
      // for (final res in result.entries) {
      //   print('Found: ${res.key} => ${res.value.map((e) => e.identifier).toList()}');
      // }
    }
    resolvedLibs.addAll({
      for (final entry in result.entries) entry.key: entry.value.map((e) => e.identifier).toSet(),
    });
  }
  printBlue('resolved in ${stopWatch.elapsedMilliseconds}ms');
  final typeResolver = AstTypeResolver(resolvedLibs, matcher().fileResolver);
  final paramResolver = AstParameterResolver(typeResolver);
  printBlue('Processing Finished: ${className} in ${stopWatch.elapsedMilliseconds}ms');
  return RouteConfig(
    className: className,
    name: className,
    pageType: ResolvedType(
      name: className,
      import: typeResolver.resolveImport(className),
    ),
    parameters: [
      for (final param in params) paramResolver.resolve(param),
    ],
  );
}
