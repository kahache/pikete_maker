import 'dart:io';

/// Static import graph of `lib/` for the security boundary locks (Q2, P2).
///
/// Deliberately a plain source scan, not the analyzer: it runs inside
/// `flutter test` with no extra dependency (pubspec untouched) and is fast.
/// It resolves `import` / `export` / `part` directives (incl. conditional
/// `if (...)` URIs) that point to `package:piketemaker/...` or a relative
/// path; everything else (`dart:*`, other packages) is an external leaf.
///
/// Limits (stated honestly, they are also in the audit report): a dynamic
/// `MethodChannel` call, a `dart:ffi` lookup or reflection are invisible to
/// an import scan. The manifest lock (no INTERNET permission) is the
/// complementary, platform-enforced guarantee.

/// Package name of the app (pubspec `name:`).
const String kAppPackage = 'piketemaker';

/// Root of the scanned sources, relative to the `app/` working directory
/// that `flutter test` runs in.
const String kLibRoot = 'lib';

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+([^;]*);''',
  multiLine: true,
);
final RegExp _quoted = RegExp(r'''['"]([^'"]+)['"]''');

/// Normalises a path to forward slashes, relative to `app/`.
String normalizePath(String path) => path.replaceAll('\\', '/');

/// Every `.dart` file under [dir] (relative to `app/`), normalised.
List<String> dartFilesUnder(String dir) {
  final Directory d = Directory(dir);
  if (!d.existsSync()) return <String>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .map((File f) => normalizePath(f.path))
      .where((String p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// The source of [file] with comments removed, so a lock never trips on (or
/// is satisfied by) prose. `//` preceded by `:` is kept (URLs in strings).
String codeWithoutComments(String file) {
  final String raw = File(file).readAsStringSync();
  return raw
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'(?<!:)//.*$', multiLine: true), '');
}

/// One resolved directive of a file.
class ImportEdge {
  ImportEdge(this.uri, this.target, this.clause);

  /// The URI exactly as written.
  final String uri;

  /// The `lib/...` path it resolves to, or null for an external URI.
  final String? target;

  /// The whole directive text (to inspect `show` / `hide` combinators).
  final String clause;

  bool get isExternal => target == null;
}

String _resolve(String fromFile, String uri) {
  final List<String> parts = fromFile.split('/')..removeLast();
  for (final String seg in uri.split('/')) {
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (seg != '.' && seg.isNotEmpty) {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// The directives of [file] (a `lib/...` path).
List<ImportEdge> importsOf(String file) {
  final String code = codeWithoutComments(file);
  final List<ImportEdge> edges = <ImportEdge>[];
  for (final RegExpMatch m in _directive.allMatches(code)) {
    final String clause = m.group(1)!;
    for (final RegExpMatch q in _quoted.allMatches(clause)) {
      final String uri = q.group(1)!;
      String? target;
      if (uri.startsWith('package:$kAppPackage/')) {
        target = '$kLibRoot/${uri.substring('package:$kAppPackage/'.length)}';
      } else if (!uri.contains(':')) {
        target = _resolve(file, uri);
      }
      edges.add(ImportEdge(uri, target, clause));
    }
  }
  return edges;
}

/// The transitive closure of [roots] inside `lib/`: every `lib/...` file
/// reachable through directives, plus every external URI met on the way
/// (mapped to the first file that imports it, for readable failures).
class Closure {
  Closure(this.files, this.externals);

  final Set<String> files;
  final Map<String, String> externals;
}

Closure closureOf(Iterable<String> roots) {
  final Set<String> seen = <String>{};
  final Map<String, String> externals = <String, String>{};
  final List<String> queue = roots.map(normalizePath).toList();
  while (queue.isNotEmpty) {
    final String file = queue.removeLast();
    if (!seen.add(file)) continue;
    if (!File(file).existsSync()) continue;
    for (final ImportEdge e in importsOf(file)) {
      if (e.isExternal) {
        externals.putIfAbsent(e.uri, () => file);
      } else if (!seen.contains(e.target)) {
        queue.add(e.target!);
      }
    }
  }
  return Closure(seen, externals);
}

/// The `lib/` files that import [packagePrefix] (e.g. `package:url_launcher`).
List<String> filesImporting(String packagePrefix) => dartFilesUnder(kLibRoot)
    .where((String f) =>
        importsOf(f).any((ImportEdge e) => e.uri.startsWith(packagePrefix)))
    .toList();
