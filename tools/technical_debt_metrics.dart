// ignore_for_file: avoid_print
// Technical Debt Metrics — suizo-argentina monorepo
//
// Run: melos run check:debt
// Or:  dart run tools/technical_debt_metrics.dart --path apps/remitos-app-new/lib/features/signature_capture
//
// Exit code 0 = reporting only (Phase 1)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const _projectRoot = '.';

/// Directories to skip entirely during recursive scanning.
const _ignoredDirs = ['.dart_tool', 'build', '.git', 'test', '.fvm', 'generated'];

/// External pub.dev package prefixes to ignore for Ce computation.
/// These are not "our" modules, so they don't count as coupling.
const _externalPackagePrefixes = [
  'dart:',
  'package:flutter/',
  'package:flutter_test/',
  'package:equatable/',
  'package:flutter_bloc/',
  'package:bloc/',
  'package:bloc_concurrency/',
  'package:freezed_annotation/',
  'package:json_annotation/',
  'package:get_it/',
  'package:injectable/',
  'package:dartz/',
  'package:rxdart/',
  'package:meta/',
  'package:signature/',
  'package:go_router/',
  'package:dio/',
  'package:shared_preferences/',
  'package:path_provider/',
  'package:image_picker/',
  'package:permission_handler/',
  'package:google_fonts/',
  'package:flutter_svg/',
  'package:shimmer/',
  'package:intl/',
  'package:formz/',
  'package:hydrated_bloc/',
  'package:connectivity_plus/',
  'package:device_info_plus/',
  'package:package_info_plus/',
  'package:local_auth/',
  'package:jwt_decoder/',
  'package:http/',
  'package:sqflite/',
  'package:path/',
  'package:firebase_',
  'package:google_mlkit_',
  'package:mobile_scanner/',
  'package:flutter_barcode_scanner/',
  'package:simple_barcode_scanner/',
  'package:geolocator/',
  'package:flutter_map/',
  'package:latlong2/',
  'package:open_route_service/',
  'package:google_maps_flutter/',
  'package:supabase_flutter/',
  'package:camera/',
  'package:url_launcher/',
  'package:font_awesome_flutter/',
  'package:delightful_toast/',
  'package:search_choices/',
  'package:flutter_dotenv/',
  'package:flutter_local_notifications/',
  'package:flutter_secure_storage/',
  'package:network_info_plus/',
  'package:dart_ipify/',
  'package:http_parser/',
  'package:flutter_localizations/',
  'package:local_auth_android/',
  'package:version_model/',
  'package:analyzer/',
  'package:custom_lint_builder/',
];

/// CC thresholds
const _ccWarning = 11;
const _ccHigh = 16;
const _ccCritical = 25;

/// Cognitive Complexity thresholds
const _cogcWarning = 11;
const _cogcHigh = 21;
const _cogcCritical = 31;

/// Nesting Depth thresholds
const _nestingWarning = 4;
const _nestingHigh = 6;
const _nestingCritical = 8;

/// LOC threshold for "large file" warning
const _locLargeFile = 300;

/// LOC threshold for "long function" warning
const _locLongFunction = 50;

// ---------------------------------------------------------------------------
// Analysis Scope — formal model
// ---------------------------------------------------------------------------

enum AnalysisScopeType {
  feature,       // apps/<app>/lib/features/<feature>
  app,           // apps/<app>
  package,       // packages/<pkg>
  appsGroup,     // apps/
  packagesGroup, // packages/
  monorepo,      // . or no --path
  unknown,
}

class AnalysisScope {
  final AnalysisScopeType type;
  final String scanRoot;

  /// Root used when scanning for Ca (incoming references).
  final String caSearchRoot;

  /// The label shown in the header.
  final String label;

  /// For scopeType=feature/app: the app name (e.g. "remitos-app-new").
  final String? appName;

  /// The Dart package name of the app (read from pubspec.yaml).
  /// Used to filter out self-referencing absolute imports in Ce.
  final String? appPackageName;

  /// For scopeType=feature: the feature name (e.g. "signature_capture").
  final String? featureName;

  /// For scopeType=package: the package name (e.g. "design_system").
  final String? packageName;

  /// Pattern used to detect when a foreign file imports the target module.
  /// For feature: "features/signature_capture"
  /// For package: "package:design_system/"
  /// For app:     "package:<app_package_name>/" (rarely used)
  final String targetImportPattern;

  const AnalysisScope({
    required this.type,
    required this.scanRoot,
    required this.caSearchRoot,
    required this.label,
    required this.targetImportPattern,
    this.appName,
    this.appPackageName,
    this.featureName,
    this.packageName,
  });
}

// ---------------------------------------------------------------------------
// AnalysisScopeResolver — detects scope from --path
// ---------------------------------------------------------------------------

class AnalysisScopeResolver {
  String _normalize(String p) => p.replaceAll('\\', '/').replaceAll(RegExp(r'/$'), '');

  /// Reads `name:` from a pubspec.yaml at the given directory, or returns null.
  String? _readPubspecName(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return null;
    for (final line in pubspec.readAsLinesSync()) {
      final m = RegExp(r'^name:\s*(\S+)').firstMatch(line);
      if (m != null) return m.group(1);
    }
    return null;
  }

  AnalysisScope resolve(String? rawPath) {
    if (rawPath == null || rawPath == '.' || rawPath.isEmpty) {
      return AnalysisScope(
        type: AnalysisScopeType.monorepo,
        scanRoot: _projectRoot,
        caSearchRoot: _projectRoot,
        label: 'monorepo',
        targetImportPattern: '',
      );
    }

    final path = _normalize(rawPath);
    final parts = path.split('/');

    // ── appsGroup ── "apps"
    if (path == 'apps') {
      return AnalysisScope(
        type: AnalysisScopeType.appsGroup,
        scanRoot: 'apps',
        caSearchRoot: _projectRoot,
        label: 'apps (group)',
        targetImportPattern: '',
      );
    }

    // ── packagesGroup ── "packages"
    if (path == 'packages') {
      return AnalysisScope(
        type: AnalysisScopeType.packagesGroup,
        scanRoot: 'packages',
        caSearchRoot: _projectRoot,
        label: 'packages (group)',
        targetImportPattern: '',
      );
    }

    // ── package ── "packages/<pkg>"
    if (parts.length == 2 && parts[0] == 'packages') {
      final pkgName = parts[1];
      return AnalysisScope(
        type: AnalysisScopeType.package,
        scanRoot: path,
        caSearchRoot: _projectRoot,
        label: pkgName,
        packageName: pkgName,
        targetImportPattern: 'package:$pkgName/',
      );
    }

    // ── app ── "apps/<app>"  (exactly 2 segments)
    if (parts.length == 2 && parts[0] == 'apps') {
      final appName = parts[1];
      final appPackageName = _readPubspecName(path);
      return AnalysisScope(
        type: AnalysisScopeType.app,
        scanRoot: path,
        caSearchRoot: _projectRoot,
        label: appName,
        appName: appName,
        appPackageName: appPackageName,
        targetImportPattern: '',
      );
    }

    // ── feature ── "apps/<app>/lib/features/<feature>"
    final featureMatch = RegExp(r'^apps/([^/]+)/(?:lib/)?features/([^/]+)$').firstMatch(path);
    if (featureMatch != null) {
      final appName = featureMatch.group(1)!;
      final featureName = featureMatch.group(2)!;
      final appPackageName = _readPubspecName('apps/$appName');
      return AnalysisScope(
        type: AnalysisScopeType.feature,
        scanRoot: path,
        caSearchRoot: 'apps/$appName/lib',
        label: featureName,
        appName: appName,
        appPackageName: appPackageName,
        featureName: featureName,
        targetImportPattern: 'features/$featureName',
      );
    }

    // ── unknown / arbitrary path ──
    final label = parts.last;
    return AnalysisScope(
      type: AnalysisScopeType.unknown,
      scanRoot: path,
      caSearchRoot: _projectRoot,
      label: label,
      targetImportPattern: label,
    );
  }
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class FileMetrics {
  final String path;
  final int loc;
  final int classCount;
  final int abstractCount;
  final int concreteCount;
  final List<FunctionMetrics> functions;
  final List<String> rawImports; // all imports (unfiltered)

  FileMetrics({
    required this.path,
    required this.loc,
    required this.classCount,
    required this.abstractCount,
    required this.concreteCount,
    required this.functions,
    required this.rawImports,
  });
}

class FunctionMetrics {
  final String name;
  final int cyclomaticComplexity;
  final int loc;

  FunctionMetrics({
    required this.name,
    required this.cyclomaticComplexity,
    required this.loc,
  });
}

// ---------------------------------------------------------------------------
// Cognitive Complexity — models
// ---------------------------------------------------------------------------

/// Per-function cognitive complexity result.
class FunctionCogcMetric {
  final String name;         // e.g. "build" or "MyWidget::build"
  final String fileName;     // short file name, e.g. "signature_screen.dart"
  final int cognitiveScore;

  const FunctionCogcMetric({
    required this.name,
    required this.fileName,
    required this.cognitiveScore,
  });
}

/// Aggregate cognitive complexity for a module (all files combined).
class CognitiveComplexityResult {
  final List<FunctionCogcMetric> functions;

  const CognitiveComplexityResult(this.functions);

  bool get isEmpty => functions.isEmpty;

  double get average {
    if (functions.isEmpty) return 0.0;
    return functions.map((f) => f.cognitiveScore).reduce((a, b) => a + b) /
        functions.length;
  }

  int get maximum {
    if (functions.isEmpty) return 0;
    return functions.map((f) => f.cognitiveScore).reduce(max);
  }

  /// Top N functions sorted by score descending.
  List<FunctionCogcMetric> top(int n) {
    final sorted = [...functions]
      ..sort((a, b) => b.cognitiveScore.compareTo(a.cognitiveScore));
    return sorted.take(n).toList();
  }
}

// ---------------------------------------------------------------------------
// CognitiveComplexityVisitor — AST-based scorer
// ---------------------------------------------------------------------------

/// Computes Cognitive Complexity (Sonar/Richards model) for a single function body.
///
/// Rules applied:
///   +1 per control structure encountered (if, else if, else, for, for-in,
///      while, do-while, switch, case/default, catch, conditional expression).
///   +nesting penalty per level of nesting at the point of the structure.
///   +1 per binary logical operator (&&, ||) — flat, no nesting bonus.
///   +1 per break / continue (flow interruption inside a structure).
class _CognitiveComplexityBodyVisitor extends RecursiveAstVisitor<void> {
  int score = 0;
  int _nesting = 0;

  // ── Nesting-bearing structures ────────────────────────────────────────────

  @override
  void visitIfStatement(IfStatement node) {
    _increment(); // +1 + nesting
    _nesting++;
    node.thenStatement.accept(this);
    _nesting--;

    final elseStmt = node.elseStatement;
    if (elseStmt != null) {
      if (elseStmt is IfStatement) {
        // "else if" — +1 flat (no nesting penalty), then recurse at same level
        score += 1;
        _nesting++;
        elseStmt.accept(this);
        _nesting--;
      } else {
        // plain "else" — +1 flat
        score += 1;
        _nesting++;
        elseStmt.accept(this);
        _nesting--;
      }
    }
    // Do NOT call super — we manually descended
  }

  @override
  void visitForStatement(ForStatement node) {
    _increment();
    _nesting++;
    super.visitForStatement(node);
    _nesting--;
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _increment();
    _nesting++;
    super.visitWhileStatement(node);
    _nesting--;
  }

  @override
  void visitDoStatement(DoStatement node) {
    _increment();
    _nesting++;
    super.visitDoStatement(node);
    _nesting--;
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _increment();
    _nesting++;
    super.visitSwitchStatement(node);
    _nesting--;
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _increment();
    _nesting++;
    super.visitSwitchExpression(node);
    _nesting--;
  }

  @override
  void visitTryStatement(TryStatement node) {
    // try itself isn't a score point; each catch clause is
    node.body.accept(this);
    for (final clause in node.catchClauses) {
      _increment();
      _nesting++;
      clause.accept(this);
      _nesting--;
    }
    node.finallyBlock?.accept(this);
    // Do NOT call super — manually descended
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    // ternary: a ? b : c
    _increment();
    _nesting++;
    node.thenExpression.accept(this);
    node.elseExpression.accept(this);
    _nesting--;
    // Do NOT call super — manually descended
  }

  // ── Flat increments (no nesting bonus) ───────────────────────────────────

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') score += 1;
    super.visitBinaryExpression(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    score += 1;
    super.visitBreakStatement(node);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    score += 1;
    super.visitContinueStatement(node);
  }

  // ── Nested function bodies reset nesting context ─────────────────────────
  // Anonymous functions / lambdas increase structural nesting but we treat
  // them as a fresh nested context (+1 for the lambda itself, then recurse).

  @override
  void visitFunctionExpression(FunctionExpression node) {
    score += 1; // entering a nested callable
    _nesting++;
    super.visitFunctionExpression(node);
    _nesting--;
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  void _increment() => score += 1 + _nesting;
}

/// Visits each top-level function / method declaration in a CompilationUnit
/// and returns per-function CogC metrics.
class _CognitiveComplexityFileVisitor extends RecursiveAstVisitor<void> {
  _CognitiveComplexityFileVisitor(this.fileName);

  final String fileName;
  final List<FunctionCogcMetric> results = [];

  // Track enclosing class name for qualified method names
  String? _className;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final prev = _className;
    _className = node.name.lexeme;
    super.visitClassDeclaration(node);
    _className = prev;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _scoreBody(node.name.lexeme, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _scoreBody(node.name.lexeme, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  void _scoreBody(String funcName, FunctionBody body) {
    final visitor = _CognitiveComplexityBodyVisitor();
    body.accept(visitor);
    if (visitor.score > 0) {
      final qualifiedName =
          _className != null ? '$_className::$funcName' : funcName;
      results.add(FunctionCogcMetric(
        name: qualifiedName,
        fileName: fileName,
        cognitiveScore: visitor.score,
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// CognitiveComplexityAnalyzer — parses a file and returns results
// ---------------------------------------------------------------------------

class CognitiveComplexityAnalyzer {
  /// Parses [file] with the analyzer AST and returns per-function CogC scores.
  /// Returns empty list if the file cannot be parsed (safe — never throws).
  List<FunctionCogcMetric> analyze(File file) {
    final normalizedPath = file.path.replaceAll('\\', '/');

    // Skip generated files
    if (normalizedPath.endsWith('.g.dart') ||
        normalizedPath.endsWith('.freezed.dart')) return [];

    try {
      final content = file.readAsStringSync();
      final result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
      final fileName = normalizedPath.split('/').last;
      final visitor = _CognitiveComplexityFileVisitor(fileName);
      result.unit.visitChildren(visitor);
      return visitor.results;
    } catch (_) {
      return [];
    }
  }
}

// ---------------------------------------------------------------------------
// Nesting Depth — models, visitor, analyzer
// ---------------------------------------------------------------------------

/// Per-function nesting depth result.
class FunctionNestingMetric {
  final String name;
  final String fileName;
  final int maxDepth;

  const FunctionNestingMetric({
    required this.name,
    required this.fileName,
    required this.maxDepth,
  });
}

/// Aggregate nesting depth for a module.
class NestingDepthResult {
  final List<FunctionNestingMetric> functions;

  const NestingDepthResult(this.functions);

  bool get isEmpty => functions.isEmpty;

  double get average {
    if (functions.isEmpty) return 0.0;
    return functions.map((f) => f.maxDepth).reduce((a, b) => a + b) /
        functions.length;
  }

  int get maximum {
    if (functions.isEmpty) return 0;
    return functions.map((f) => f.maxDepth).reduce(max);
  }

  List<FunctionNestingMetric> top(int n) {
    final sorted = [...functions]
      ..sort((a, b) => b.maxDepth.compareTo(a.maxDepth));
    return sorted.take(n).toList();
  }
}

/// Measures the maximum nesting depth within a single function body.
///
/// Every control structure and lambda/callback that introduces a new block
/// increments the depth counter. The visitor tracks the running depth and
/// records the peak seen.
///
/// Counted structures:
///   if / else-if / else, for, while, do-while, switch (statement & expression),
///   catch, try-finally, conditional expression (ternary), function expression
///   (lambdas / builder callbacks).
class _NestingDepthBodyVisitor extends RecursiveAstVisitor<void> {
  int _current = 0;
  int maxDepth = 0;

  void _enter() {
    _current++;
    if (_current > maxDepth) maxDepth = _current;
  }

  void _leave() => _current--;

  // ── Control structures ────────────────────────────────────────────────────

  @override
  void visitIfStatement(IfStatement node) {
    _enter();
    node.thenStatement.accept(this);
    _leave();

    final elseStmt = node.elseStatement;
    if (elseStmt != null) {
      if (elseStmt is IfStatement) {
        // else-if: same nesting level as the if — recurse directly (no extra enter)
        elseStmt.accept(this);
      } else {
        _enter();
        elseStmt.accept(this);
        _leave();
      }
    }
    // Intentionally NOT calling super — manually descended
  }

  @override
  void visitForStatement(ForStatement node) {
    _enter();
    super.visitForStatement(node);
    _leave();
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _enter();
    super.visitWhileStatement(node);
    _leave();
  }

  @override
  void visitDoStatement(DoStatement node) {
    _enter();
    super.visitDoStatement(node);
    _leave();
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _enter();
    super.visitSwitchStatement(node);
    _leave();
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _enter();
    super.visitSwitchExpression(node);
    _leave();
  }

  @override
  void visitTryStatement(TryStatement node) {
    // try body counts as one nesting level
    _enter();
    node.body.accept(this);
    _leave();
    // each catch clause is another level
    for (final clause in node.catchClauses) {
      _enter();
      clause.accept(this);
      _leave();
    }
    if (node.finallyBlock != null) {
      _enter();
      node.finallyBlock!.accept(this);
      _leave();
    }
    // Intentionally NOT calling super — manually descended
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    // ternary a ? b : c
    _enter();
    node.thenExpression.accept(this);
    node.elseExpression.accept(this);
    _leave();
    // Intentionally NOT calling super — manually descended
  }

  // ── Lambdas / builder callbacks ───────────────────────────────────────────

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _enter();
    super.visitFunctionExpression(node);
    _leave();
  }
}

/// Visits each method/function in a file and records per-function max nesting.
class _NestingDepthFileVisitor extends RecursiveAstVisitor<void> {
  _NestingDepthFileVisitor(this.fileName);

  final String fileName;
  final List<FunctionNestingMetric> results = [];
  String? _className;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final prev = _className;
    _className = node.name.lexeme;
    super.visitClassDeclaration(node);
    _className = prev;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _scoreBody(node.name.lexeme, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _scoreBody(node.name.lexeme, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  void _scoreBody(String funcName, FunctionBody body) {
    final visitor = _NestingDepthBodyVisitor();
    body.accept(visitor);
    if (visitor.maxDepth > 0) {
      final qualifiedName =
          _className != null ? '$_className::$funcName' : funcName;
      results.add(FunctionNestingMetric(
        name: qualifiedName,
        fileName: fileName,
        maxDepth: visitor.maxDepth,
      ));
    }
  }
}

/// Parses a Dart file with `package:analyzer` and returns per-function nesting metrics.
/// Safe: returns empty list on parse failure or for generated files.
class NestingDepthAnalyzer {
  List<FunctionNestingMetric> analyze(File file) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    if (normalizedPath.endsWith('.g.dart') ||
        normalizedPath.endsWith('.freezed.dart')) return [];

    try {
      final content = file.readAsStringSync();
      final result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
      final fileName = normalizedPath.split('/').last;
      final visitor = _NestingDepthFileVisitor(fileName);
      result.unit.visitChildren(visitor);
      return visitor.results;
    } catch (_) {
      return [];
    }
  }
}

/// Classifies an afferent dependency as functional (a real feature/module consumer)
/// or technical (composition root, DI container, routing, main entry points).
enum CaKind { functional, technical }

class AfferentDep {
  final String label;
  final CaKind kind;
  const AfferentDep(this.label, this.kind);
}

class ModuleMetrics {
  final AnalysisScope scope;
  final List<FileMetrics> files;
  final int efferentCoupling;
  final List<String> outgoingDependencies;

  /// All afferent deps with their kind classification.
  final List<AfferentDep> afferentDeps;

  /// Cognitive complexity results for all functions in the module.
  final CognitiveComplexityResult cogc;

  /// Nesting depth results for all functions in the module.
  final NestingDepthResult nesting;

  ModuleMetrics({
    required this.scope,
    required this.files,
    required this.efferentCoupling,
    required this.outgoingDependencies,
    required this.afferentDeps,
    required this.cogc,
    required this.nesting,
  });

  int get totalLoc => files.fold(0, (s, f) => s + f.loc);
  int get totalClasses => files.fold(0, (s, f) => s + f.classCount);
  int get totalAbstractCount => files.fold(0, (s, f) => s + f.abstractCount);
  int get totalConcreteCount => files.fold(0, (s, f) => s + f.concreteCount);
  List<FunctionMetrics> get allFunctions => files.expand((f) => f.functions).toList();

  int get afferentCoupling => afferentDeps.length;

  List<String> get incomingDependencies =>
      afferentDeps.map((d) => d.label).toList()..sort();

  List<AfferentDep> get afferentFunctional =>
      afferentDeps.where((d) => d.kind == CaKind.functional).toList()..sort((a, b) => a.label.compareTo(b.label));

  List<AfferentDep> get afferentTechnical =>
      afferentDeps.where((d) => d.kind == CaKind.technical).toList()..sort((a, b) => a.label.compareTo(b.label));

  double get instability {
    final total = efferentCoupling + afferentCoupling;
    if (total == 0) return 0.0;
    return efferentCoupling / total;
  }

  /// A = abstractArtifacts / totalArtifacts
  double get abstractionRatio {
    final total = totalAbstractCount + totalConcreteCount;
    if (total == 0) return 0.0;
    return totalAbstractCount / total;
  }

  /// D = |A + I - 1|  (distance from the main sequence)
  double get mainSequenceDistance => (abstractionRatio + instability - 1.0).abs();
}

// ---------------------------------------------------------------------------
// Scanner — collects .dart files recursively (safe: per-dir listSync)
// ---------------------------------------------------------------------------

class DartScanner {
  Future<List<File>> scan(String rootPath) async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) {
      print('  ERROR: path "$rootPath" does not exist.');
      exit(1);
    }
    final files = <File>[];
    _scanRecursive(dir, files);
    return files;
  }

  void _scanRecursive(Directory dir, List<File> files) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final entity in entries) {
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      if (entity is Directory) {
        if (!_ignoredDirs.contains(name)) _scanRecursive(entity, files);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Parser — extracts metrics from a single .dart file
// ---------------------------------------------------------------------------

class DartFileParser {
  FileMetrics parse(File file) {
    final normalizedPath = file.path.replaceAll('\\', '/');

    // Skip generated files — they inflate counts without design signal
    if (normalizedPath.endsWith('.g.dart') || normalizedPath.endsWith('.freezed.dart')) {
      return FileMetrics(
        path: normalizedPath,
        loc: 0,
        classCount: 0,
        abstractCount: 0,
        concreteCount: 0,
        functions: [],
        rawImports: [],
      );
    }

    final lines = file.readAsLinesSync();
    final content = lines.join('\n');

    final counts = _countArtifacts(content);

    return FileMetrics(
      path: normalizedPath,
      loc: _countLoc(lines),
      classCount: counts.$1 + counts.$2,
      abstractCount: counts.$1,
      concreteCount: counts.$2,
      functions: _parseFunctions(lines),
      rawImports: _parseAllImports(lines),
    );
  }

  int _countLoc(List<String> lines) => lines.where((l) {
        final t = l.trim();
        return t.isNotEmpty && !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      }).length;

  /// Returns (abstractCount, concreteCount) without double-counting.
  ///
  /// Abstract artifacts (counted first, line marked as consumed):
  ///   abstract class, abstract interface class, abstract mixin class,
  ///   interface class, mixin (declaration)
  ///
  /// Concrete artifacts (only if line not already counted as abstract):
  ///   class, final class, base class, sealed class
  ///   (enum is deliberately excluded — not a design-layer artifact)
  (int, int) _countArtifacts(String content) {
    int abstractCount = 0;
    int concreteCount = 0;

    // Process line-by-line to avoid double counting
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();

      // Skip comments
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('/*')) continue;

      // ── Abstract patterns (order matters: most specific first) ──
      if (_matchesAbstract(line)) {
        abstractCount++;
        continue; // consumed — don't also count as concrete
      }

      // ── Concrete patterns ──
      if (_matchesConcrete(line)) {
        concreteCount++;
      }
    }

    return (abstractCount, concreteCount);
  }

  bool _matchesAbstract(String line) {
    // abstract interface class Foo
    if (RegExp(r'\babstract\s+interface\s+class\s+\w+').hasMatch(line)) return true;
    // abstract mixin class Foo
    if (RegExp(r'\babstract\s+mixin\s+class\s+\w+').hasMatch(line)) return true;
    // abstract class Foo
    if (RegExp(r'\babstract\s+class\s+\w+').hasMatch(line)) return true;
    // interface class Foo (non-abstract but non-instantiable contract)
    if (RegExp(r'\binterface\s+class\s+\w+').hasMatch(line)) return true;
    // mixin Foo (standalone mixin declaration, not mixin class)
    if (RegExp(r'\bmixin\s+\w+(?!\s+class)').hasMatch(line)) return true;
    return false;
  }

  bool _matchesConcrete(String line) {
    // final class Foo
    if (RegExp(r'\bfinal\s+class\s+\w+').hasMatch(line)) return true;
    // base class Foo
    if (RegExp(r'\bbase\s+class\s+\w+').hasMatch(line)) return true;
    // sealed class Foo
    if (RegExp(r'\bsealed\s+class\s+\w+').hasMatch(line)) return true;
    // plain class Foo — must NOT be preceded by abstract/interface/final/base/sealed
    if (RegExp(r'(?<!\w)class\s+\w+').hasMatch(line) &&
        !RegExp(r'\b(abstract|interface|final|base|sealed)\b').hasMatch(line)) {
      return true;
    }
    return false;
  }

  List<String> _parseAllImports(List<String> lines) {
    final imports = <String>[];
    final pattern = RegExp(r"^import\s+'([^']+)'");
    for (final line in lines) {
      final match = pattern.firstMatch(line.trim());
      if (match != null) imports.add(match.group(1)!);
    }
    return imports;
  }

  List<FunctionMetrics> _parseFunctions(List<String> lines) {
    final functions = <FunctionMetrics>[];
    final funcPattern = RegExp(
      r'^\s*(?:Future|Stream|void|bool|int|double|String|List|Map|Set|Widget|dynamic|\w+\??)\s+(\w+)\s*\(',
    );

    int? funcStart;
    String? funcName;
    int braceDepth = 0;
    bool inFunction = false;
    int funcBraceStart = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (!inFunction) {
        final match = funcPattern.firstMatch(line);
        if (match != null && !trimmed.startsWith('//') && !trimmed.startsWith('*')) {
          final name = match.group(1)!;
          if (!_isKeyword(name)) {
            funcName = name;
            funcStart = i;
            inFunction = true;
            braceDepth = 0;
            funcBraceStart = 0;
          }
        }
      }

      if (inFunction) {
        for (final char in line.split('')) {
          if (char == '{') {
            braceDepth++;
            if (funcBraceStart == 0) funcBraceStart = braceDepth;
          } else if (char == '}') {
            braceDepth--;
          }
        }
        if (funcBraceStart > 0 && braceDepth < funcBraceStart) {
          final funcLines = lines.sublist(funcStart!, i + 1);
          final cc = _computeCC(funcLines.join('\n'));
          final funcLoc = funcLines.where((l) {
            final t = l.trim();
            return t.isNotEmpty && !t.startsWith('//');
          }).length;
          functions.add(FunctionMetrics(name: funcName!, cyclomaticComplexity: cc, loc: funcLoc));
          inFunction = false;
          funcName = null;
          funcStart = null;
          braceDepth = 0;
          funcBraceStart = 0;
        }
      }
    }
    return functions;
  }

  int _computeCC(String body) {
    int cc = 1;
    for (final p in [
      RegExp(r'\bif\b'),
      RegExp(r'\belse if\b'),
      RegExp(r'\bfor\b'),
      RegExp(r'\bwhile\b'),
      RegExp(r'\bcase\b'),
      RegExp(r'\bcatch\b'),
      RegExp(r'&&'),
      RegExp(r'\|\|'),
      RegExp(r'\?(?!\?)(?!\s*\.)'),
    ]) {
      cc += p.allMatches(body).length;
    }
    return cc;
  }

  bool _isKeyword(String n) => const {
        'if', 'for', 'while', 'switch', 'catch', 'return', 'class', 'extends',
        'implements', 'with', 'import', 'export', 'abstract', 'static', 'final',
        'const', 'var', 'new', 'super', 'this', 'null', 'true', 'false',
      }.contains(n);
}

// ---------------------------------------------------------------------------
// CouplingAnalyzer — scope-aware Ce and Ca computation
// ---------------------------------------------------------------------------

class CouplingAnalyzer {
  // ── Ce ────────────────────────────────────────────────────────────────────
  //
  // Returns unique internal/monorepo modules that the target files import.
  // Filters out all external pub.dev packages.

  Map<String, Set<String>> computeEfferent(
    List<FileMetrics> targetFiles,
    AnalysisScope scope,
  ) {
    // moduleLabel → set of source files that import it
    final outgoing = <String, Set<String>>{};

    for (final file in targetFiles) {
      for (final imp in file.rawImports) {
        if (_isExternalPackage(imp)) continue;

        final modLabel = _efferentLabel(imp, scope);
        if (modLabel == null) continue;
        // Don't count the module itself
        if (modLabel == scope.label) continue;
        if (scope.featureName != null && modLabel == scope.featureName) continue;

        outgoing.putIfAbsent(modLabel, () => <String>{}).add(file.path);
      }
    }

    return outgoing;
  }

  bool _isExternalPackage(String imp) =>
      _externalPackagePrefixes.any((p) => imp.startsWith(p));

  /// Returns a human-readable label for what `imp` refers to.
  /// Returns null if the import should be ignored (e.g. self-reference or own-app absolute import).
  String? _efferentLabel(String imp, AnalysisScope scope) {
    // package:<name>/... → <name>
    final pkgMatch = RegExp(r'^package:([^/]+)').firstMatch(imp);
    if (pkgMatch != null) {
      final pkgName = pkgMatch.group(1)!;
      // Skip the app's own package used for absolute internal imports.
      // Use the real package name from pubspec.yaml when available,
      // falling back to a heuristic sanitization.
      if (scope.appPackageName != null && pkgName == scope.appPackageName) return null;
      if (scope.appName != null) {
        final sanitized = scope.appName!.replaceAll('-', '_');
        if (pkgName == sanitized || pkgName == scope.appName) return null;
      }
      return pkgName;
    }

    // Relative path: strip leading ../ and extract first meaningful segment
    final stripped = imp.replaceAll(RegExp(r'^(\.\./)+'), '');
    final parts = stripped.split('/');
    if (parts.isEmpty) return null;

    // For feature scope, skip self-relative imports within the feature
    if (scope.type == AnalysisScopeType.feature && scope.featureName != null) {
      // e.g. "./cubit/foo.dart" or "cubit/foo.dart" — still inside the feature
      if (!stripped.contains('/') || parts.first == 'cubit' || parts.first == 'widgets' ||
          parts.first == 'screens' || parts.first == 'domain' || parts.first == 'data' ||
          parts.first == 'presentation') {
        // Likely internal to the feature — not a cross-feature dependency
        // Only count if it clearly references another feature/module
        return null;
      }
      // If it starts with "features/" → the next segment is the feature name
      if (parts.first == 'features' && parts.length > 1) {
        return parts[1] == scope.featureName ? null : parts[1];
      }
    }

    return parts.first.isNotEmpty ? parts.first : null;
  }

  // ── Ca ────────────────────────────────────────────────────────────────────
  //
  // Scans caSearchRoot for files that import the target module.
  // Returns a map of label → AfferentDep (with functional/technical classification).

  Map<String, AfferentDep> computeAfferent(
    List<FileMetrics> caFiles,
    List<FileMetrics> targetFiles,
    AnalysisScope scope,
  ) {
    if (scope.targetImportPattern.isEmpty &&
        scope.type != AnalysisScopeType.app) {
      return {};
    }

    final targetPaths = targetFiles.map((f) => f.path).toSet();
    final incoming = <String, AfferentDep>{};

    for (final file in caFiles) {
      final normalizedFilePath = file.path.replaceAll('\\', '/');
      if (targetPaths.contains(normalizedFilePath)) continue;

      final normalizedScanRoot = scope.scanRoot.replaceAll('\\', '/');
      if (normalizedFilePath.startsWith(normalizedScanRoot + '/') ||
          normalizedFilePath.startsWith('./' + normalizedScanRoot + '/')) {
        continue;
      }

      for (final imp in file.rawImports) {
        if (_importsTarget(imp, scope)) {
          final label = _afferentLabel(normalizedFilePath, scope);
          if (label != null && !incoming.containsKey(label)) {
            final kind = _classifyAfferent(normalizedFilePath, label);
            incoming[label] = AfferentDep(label, kind);
          }
          break;
        }
      }
    }

    return incoming;
  }

  /// Classifies a caller as functional or technical.
  ///
  /// Technical callers are:
  /// - DI / injection containers
  /// - Routing / navigation setup
  /// - Main entry points
  /// - Module registration files
  CaKind _classifyAfferent(String filePath, String label) {
    final p = filePath.replaceAll('\\', '/').toLowerCase();
    final l = label.toLowerCase();

    // File-name based signals (check the actual file name)
    final fileName = p.split('/').last;
    const technicalFilePatterns = [
      'injection_container',
      'injectable',
      'get_it',
      'di_container',
      'service_locator',
      'locator',
      'router',
      'routes',
      'app_router',
      'go_router',
      'navigation',
      'main',
      'bootstrap',
      'app_module',
      'module',
      'register',
      'setup',
      'configurator',
      'provider',         // top-level provider setup files
      'dependency',
    ];

    for (final pattern in technicalFilePatterns) {
      if (fileName.contains(pattern)) return CaKind.technical;
    }

    // Label-based signals (the feature/folder name)
    const technicalLabelPatterns = [
      'injection_container',
      'injection_container.dart',
      'app_root',
      'main',
      'router',
      'routes',
      'di',
      'locator',
      'bootstrap',
    ];

    for (final pattern in technicalLabelPatterns) {
      if (l == pattern || l.contains(pattern)) return CaKind.technical;
    }

    return CaKind.functional;
  }

  bool _importsTarget(String imp, AnalysisScope scope) {
    if (scope.targetImportPattern.isEmpty) return false;
    return imp.contains(scope.targetImportPattern);
  }

  /// Returns the label that identifies the *caller* module.
  String? _afferentLabel(String filePath, AnalysisScope scope) {
    final p = filePath.replaceAll('\\', '/');

    switch (scope.type) {
      case AnalysisScopeType.feature:
        // Caller is inside the same app → identify by feature or top-level folder
        // apps/<app>/lib/features/<other_feature>/...  → <other_feature>
        final featMatch = RegExp(r'apps/[^/]+/lib/features/([^/]+)').firstMatch(p);
        if (featMatch != null) {
          final callerFeature = featMatch.group(1)!;
          return callerFeature == scope.featureName ? null : callerFeature;
        }
        // apps/<app>/lib/<folder>/...  → <folder>
        final folderMatch = RegExp(r'apps/[^/]+/lib/([^/]+)').firstMatch(p);
        if (folderMatch != null) return folderMatch.group(1);
        // apps/<app>/lib/<file>.dart  → app_root
        if (RegExp(r'apps/[^/]+/lib/[^/]+\.dart$').hasMatch(p)) return 'app_root';
        return null;

      case AnalysisScopeType.package:
        // Caller can be any app or package
        final appMatch = RegExp(r'apps/([^/]+)').firstMatch(p);
        if (appMatch != null) return appMatch.group(1);
        final pkgMatch = RegExp(r'packages/([^/]+)').firstMatch(p);
        if (pkgMatch != null) return pkgMatch.group(1);
        return null;

      case AnalysisScopeType.app:
        // Who imports this app? Typically nothing (apps are leaves).
        final appMatch = RegExp(r'apps/([^/]+)').firstMatch(p);
        if (appMatch != null) {
          final caller = appMatch.group(1);
          return caller == scope.appName ? null : caller;
        }
        final pkgMatch = RegExp(r'packages/([^/]+)').firstMatch(p);
        if (pkgMatch != null) return pkgMatch.group(1);
        return null;

      default:
        // monorepo / group / unknown — extract top-level module
        final appsMatch = RegExp(r'apps/([^/]+)').firstMatch(p);
        if (appsMatch != null) return appsMatch.group(1);
        final pkgsMatch = RegExp(r'packages/([^/]+)').firstMatch(p);
        if (pkgsMatch != null) return pkgsMatch.group(1);
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// MetricsAggregator — assembles ModuleMetrics
// ---------------------------------------------------------------------------

class MetricsAggregator {
  final CouplingAnalyzer _coupling = CouplingAnalyzer();
  final CognitiveComplexityAnalyzer _cogcAnalyzer = CognitiveComplexityAnalyzer();
  final NestingDepthAnalyzer _nestingAnalyzer = NestingDepthAnalyzer();

  ModuleMetrics compute({
    required AnalysisScope scope,
    required List<FileMetrics> targetFiles,
    required List<FileMetrics> caFiles,
    required List<File> targetRawFiles,
  }) {
    final ceMap = _coupling.computeEfferent(targetFiles, scope);
    final caMap = _coupling.computeAfferent(caFiles, targetFiles, scope);

    final cogcFunctions = targetRawFiles
        .expand((f) => _cogcAnalyzer.analyze(f))
        .toList();

    final nestingFunctions = targetRawFiles
        .expand((f) => _nestingAnalyzer.analyze(f))
        .toList();

    return ModuleMetrics(
      scope: scope,
      files: targetFiles,
      efferentCoupling: ceMap.length,
      outgoingDependencies: ceMap.keys.toList()..sort(),
      afferentDeps: caMap.values.toList(),
      cogc: CognitiveComplexityResult(cogcFunctions),
      nesting: NestingDepthResult(nestingFunctions),
    );
  }
}

// ---------------------------------------------------------------------------
// MetricsReporter — console output
// ---------------------------------------------------------------------------

class MetricsReporter {
  void report(ModuleMetrics m) {
    final scope = m.scope;
    final allFunctions = m.allFunctions;
    final ccValues = allFunctions.map((f) => f.cyclomaticComplexity).toList();
    final avgCC = ccValues.isEmpty ? 0.0 : ccValues.reduce((a, b) => a + b) / ccValues.length;
    final maxCC = ccValues.isEmpty ? 0 : ccValues.reduce(max);

    final topComplex = [...allFunctions]
      ..sort((a, b) => b.cyclomaticComplexity.compareTo(a.cyclomaticComplexity));
    final top3 = topComplex.where((f) => f.cyclomaticComplexity > 1).take(3).toList();

    final largestFile =
        m.files.isEmpty ? null : m.files.reduce((a, b) => a.loc > b.loc ? a : b);
    final longestFunc =
        allFunctions.isEmpty ? null : allFunctions.reduce((a, b) => a.loc > b.loc ? a : b);

    final instability = m.instability;

    // ── Header ──
    print('');
    print('══════════════════════════════════════════════════════════');
    print('  Technical Debt Metrics — ${scope.label}');
    print('  Scope   : ${_scopeTypeLabel(scope.type)}');
    if (scope.appName != null) print('  App     : ${scope.appName}');
    if (scope.featureName != null) print('  Feature : ${scope.featureName}');
    if (scope.packageName != null) print('  Package : ${scope.packageName}');
    print('══════════════════════════════════════════════════════════');
    print('');

    // ── Basic stats ──
    print('  Archivos analizados : ${m.files.length}');
    print('  LOC aproximado      : ${m.totalLoc}');
    print('  Clases totales      : ${m.totalClasses}');
    print('  Funciones totales   : ${allFunctions.length}');
    print('');

    // ── Cyclomatic Complexity ──
    print('  ── Complejidad Ciclomática ────────────────────────────');
    print('  ${_ccIcon(avgCC.round())} promedio : ${avgCC.toStringAsFixed(1)}');
    print('  ${_ccIcon(maxCC)} máximo   : $maxCC');
    if (top3.isNotEmpty) {
      print('');
      print('  Funciones más complejas:');
      for (final fn in top3) {
        print('  ${_ccIcon(fn.cyclomaticComplexity)} CC=${fn.cyclomaticComplexity.toString().padLeft(3)}  ${fn.name}()');
      }
    }
    print('');

    // ── Cognitive Complexity ──
    final cogc = m.cogc;
    print('  ── Complejidad Cognitiva (CogC) ───────────────────────');
    if (cogc.isEmpty) {
      print('  ℹ️  Sin datos (ninguna función con score > 0)');
    } else {
      print('  ${_cogcIcon(cogc.average.round())} promedio : ${cogc.average.toStringAsFixed(1)}');
      print('  ${_cogcIcon(cogc.maximum)} máximo   : ${cogc.maximum}');
      final top5 = cogc.top(5).where((f) => f.cognitiveScore >= _cogcWarning).toList();
      if (top5.isNotEmpty) {
        print('');
        print('  Funciones con mayor complejidad cognitiva:');
        for (final fn in top5) {
          print('  ${_cogcIcon(fn.cognitiveScore)} CogC=${fn.cognitiveScore.toString().padLeft(3)}  ${fn.name}  (${fn.fileName})');
        }
      }
    }
    print('');

    // ── Nesting Depth ──
    final nesting = m.nesting;
    print('  ── Nesting Depth ──────────────────────────────────────');
    if (nesting.isEmpty) {
      print('  ℹ️  Sin datos (ninguna función con nesting > 0)');
    } else {
      print('  ${_nestingIcon(nesting.average.round())} promedio : ${nesting.average.toStringAsFixed(1)}');
      print('  ${_nestingIcon(nesting.maximum)} máximo   : ${nesting.maximum}');
      final topNesting = nesting.top(5).where((f) => f.maxDepth >= _nestingWarning).toList();
      if (topNesting.isNotEmpty) {
        print('');
        print('  Funciones con mayor anidamiento:');
        for (final fn in topNesting) {
          print('  ${_nestingIcon(fn.maxDepth)} Depth=${fn.maxDepth.toString().padLeft(2)}  ${fn.name}  (${fn.fileName})');
        }
      }
    }
    print('');

    // ── Efferent Coupling (Ce) ──
    print('  ── Acoplamiento Eferente (Ce) ─────────────────────────');
    print('  ${_ceIcon(m.efferentCoupling)} Ce = ${m.efferentCoupling}');
    if (m.outgoingDependencies.isNotEmpty) {
      print('  Dependencias salientes:');
      for (final dep in m.outgoingDependencies) print('    - $dep');
    } else {
      print('  (sin dependencias internas detectadas)');
    }
    print('');

    // ── Afferent Coupling (Ca) ──
    print('  ── Acoplamiento Aferente (Ca) ─────────────────────────');
    print('  ✅ Ca = ${m.afferentCoupling}');

    final caFunctional = m.afferentFunctional;
    final caTechnical = m.afferentTechnical;

    if (m.afferentCoupling == 0) {
      print('  (ningún módulo importa este scope)');
    } else {
      if (caFunctional.isNotEmpty) {
        print('  Ca funcional (${caFunctional.length}) — features/módulos consumidores:');
        for (final dep in caFunctional) print('    - ${dep.label}');
      } else {
        print('  Ca funcional (0) — ningún feature consume este módulo directamente');
      }
      if (caTechnical.isNotEmpty) {
        print('  Ca técnico  (${caTechnical.length}) — DI / routing / composition root:');
        for (final dep in caTechnical) print('    - ${dep.label}');
      }
    }
    print('');

    // ── Instability ──
    final instStr = instability.toStringAsFixed(2);
    final instLabel = instability <= 0.3
        ? 'estable'
        : instability <= 0.7
            ? 'moderado'
            : 'inestable';
    print('  ── Inestabilidad (I = Ce / (Ca + Ce)) ─────────────────');
    print('  ℹ️  I = $instStr  ($instLabel)');
    print('     0.0 = muy estable / reutilizable');
    print('     1.0 = muy inestable / dependiente');
    print('');

    // ── Abstraction & Main Sequence Distance ──
    final a = m.abstractionRatio;
    final d = m.mainSequenceDistance;
    final aStr = a.toStringAsFixed(2);
    final dStr = d.toStringAsFixed(2);
    print('  ── Abstracción / Secuencia Principal ──────────────────');
    print('  ℹ️  A = $aStr   (abstractos: ${m.totalAbstractCount}  concretos: ${m.totalConcreteCount})');
    print('  ℹ️  D = $dStr');
    print('     D = |A + I - 1|  (0.0 = zona ideal)');
    print('     Evaluación contextual: ver Policy Evaluation');
    print('');

    // ── Size ──
    print('  ── Tamaño ─────────────────────────────────────────────');
    if (largestFile != null) {
      final icon = largestFile.loc > _locLargeFile ? '⚠️ ' : '✅';
      print('  $icon archivo más grande : ${_shortPath(largestFile.path)} (${largestFile.loc} LOC)');
    }
    if (longestFunc != null) {
      final icon = longestFunc.loc > _locLongFunction ? '⚠️ ' : '✅';
      print('  $icon función más larga  : ${longestFunc.name}() (${longestFunc.loc} LOC)');
    }
    print('');

    // ── Result ──
    print('  ── Resultado ──────────────────────────────────────────');
    final hasWarnings = avgCC >= _ccWarning ||
        maxCC >= _ccWarning ||
        cogc.maximum >= _cogcHigh ||
        nesting.maximum >= _nestingHigh ||
        (largestFile != null && largestFile.loc > _locLargeFile);
    final hasCritical = maxCC >= _ccCritical ||
        cogc.maximum >= _cogcCritical ||
        nesting.maximum >= _nestingCritical;

    if (hasCritical) {
      print('  🚨 Deuda técnica crítica detectada');
    } else if (hasWarnings) {
      print('  ⚠️  Aprobado con advertencias');
    } else {
      print('  ✅ Sin deuda técnica significativa detectada');
    }

    print('');
    print('  NOTA: Este sistema es solo de reporte. No bloquea CI.');
    print('══════════════════════════════════════════════════════════');
    print('');
  }

  // ── grouped report for appsGroup / packagesGroup ──
  void reportGrouped(List<ModuleMetrics> modules, String groupLabel, AnalysisScopeType groupType) {
    print('');
    print('══════════════════════════════════════════════════════════');
    print('  Technical Debt Metrics — $groupLabel');
    print('  Scope   : ${_scopeTypeLabel(groupType)}');
    print('══════════════════════════════════════════════════════════');
    print('');

    for (final m in modules) {
      final allFunctions = m.allFunctions;
      final ccValues = allFunctions.map((f) => f.cyclomaticComplexity).toList();
      final avgCC = ccValues.isEmpty ? 0.0 : ccValues.reduce((a, b) => a + b) / ccValues.length;
      final maxCC = ccValues.isEmpty ? 0 : ccValues.reduce(max);

      print('  ┌─ ${m.scope.label}');
      print('  │  LOC=${m.totalLoc.toString().padLeft(6)}  '
          'files=${m.files.length.toString().padLeft(4)}  '
          'CC avg=${avgCC.toStringAsFixed(1).padLeft(5)}  '
          'CC max=${maxCC.toString().padLeft(4)}  '
          'CogC avg=${m.cogc.average.toStringAsFixed(1).padLeft(5)}  '
          'CogC max=${m.cogc.maximum.toString().padLeft(4)}  '
          'Nest max=${m.nesting.maximum.toString().padLeft(3)}  '
          'Ce=${m.efferentCoupling.toString().padLeft(3)}  '
          'Ca=${m.afferentCoupling.toString().padLeft(3)}  '
          'I=${m.instability.toStringAsFixed(2)}');
      print('  │  ${_resultLabel(avgCC, maxCC, m.cogc.maximum, m.nesting.maximum)}');
      print('  └──────────────────────────────────────────────────');
      print('');
    }

    print('  NOTA: Este sistema es solo de reporte. No bloquea CI.');
    print('══════════════════════════════════════════════════════════');
    print('');
  }

  String _scopeTypeLabel(AnalysisScopeType t) => switch (t) {
        AnalysisScopeType.feature => 'feature',
        AnalysisScopeType.app => 'app',
        AnalysisScopeType.package => 'package',
        AnalysisScopeType.appsGroup => 'apps (group)',
        AnalysisScopeType.packagesGroup => 'packages (group)',
        AnalysisScopeType.monorepo => 'monorepo',
        AnalysisScopeType.unknown => 'unknown',
      };

  String _ccIcon(int cc) {
    if (cc >= _ccCritical) return '🚨';
    if (cc >= _ccHigh) return '❌';
    if (cc >= _ccWarning) return '⚠️ ';
    return '✅';
  }

  String _cogcIcon(int cogc) {
    if (cogc >= _cogcCritical) return '🚨';
    if (cogc >= _cogcHigh) return '❌';
    if (cogc >= _cogcWarning) return '⚠️ ';
    return '✅';
  }

  String _nestingIcon(int depth) {
    if (depth >= _nestingCritical) return '🚨';
    if (depth >= _nestingHigh) return '❌';
    if (depth >= _nestingWarning) return '⚠️ ';
    return '✅';
  }

  String _ceIcon(int v) {
    if (v > 10) return '🚨';
    if (v > 6) return '⚠️ ';
    return '✅';
  }

  String _resultLabel(double avgCC, int maxCC, [int maxCogc = 0, int maxNesting = 0]) {
    if (maxCC >= _ccCritical || maxCogc >= _cogcCritical || maxNesting >= _nestingCritical) {
      return '🚨 deuda crítica';
    }
    if (avgCC >= _ccWarning || maxCC >= _ccWarning ||
        maxCogc >= _cogcHigh || maxNesting >= _nestingHigh) {
      return '⚠️  advertencias';
    }
    return '✅ OK';
  }

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.length > 2 ? parts.sublist(parts.length - 2).join('/') : path;
  }

  // ── Policy Evaluation report ──────────────────────────────────────────────

  void reportPolicy(List<PolicyEvaluation> evals, AnalysisScope scope,
      EnforcementMode enforcement) {
    if (evals.isEmpty) {
      print('  ── Policy Evaluation ──────────────────────────────────');
      print('  ℹ️  Sin política configurada para scope "${scope.type.name}".');
      print('');
      return;
    }

    final scopeKey = switch (scope.type) {
      AnalysisScopeType.feature => 'feature',
      AnalysisScopeType.app => 'app',
      AnalysisScopeType.package => 'package',
      AnalysisScopeType.monorepo => 'monorepo',
      _ => scope.type.name,
    };

    final enfLabel = switch (enforcement) {
      EnforcementMode.reportOnly => 'report_only',
      EnforcementMode.failOnError => 'fail_on_error',
      EnforcementMode.failOnRegression => 'fail_on_regression',
    };

    print('  ── Policy Evaluation ──────────────────────────────────');
    print('  Scope policy  : $scopeKey');
    print('  Enforcement   : $enfLabel');
    print('');

    for (final e in evals) {
      _printEval(e, scopeKey);
    }

    // Overall result
    final worst = evals.map((e) => e.severity).fold(
        PolicySeverity.ok,
        (prev, s) => s.index > prev.index ? s : prev);

    print('  Resultado política:');
    switch (worst) {
      case PolicySeverity.error:
        print('  ❌ Incumple política (error)');
      case PolicySeverity.warning:
        print('  ⚠️  Cumple con advertencias');
      case PolicySeverity.informational:
      case PolicySeverity.ok:
        print('  ✅ Cumple política');
    }
    print('');
  }

  void _printEval(PolicyEvaluation e, String scopeKey) {
    final r = e.rule;
    final actualStr = e.actual is double
        ? e.actual.toStringAsFixed(2)
        : e.actual.toString();

    switch (e.severity) {
      case PolicySeverity.ok:
        print('  ✅ ${r.metricName.padRight(32)}: $actualStr  (OK)');
      case PolicySeverity.warning:
        print('  ⚠️  ${r.metricName.padRight(31)}: $actualStr');
        if (r.warningThreshold != null) print('     warning: ${r.warningThreshold}  error: ${r.errorThreshold ?? "—"}');
      case PolicySeverity.error:
        print('  ❌ ${r.metricName.padRight(32)}: $actualStr');
        if (r.errorThreshold != null) print('     warning: ${r.warningThreshold ?? "—"}  error: ${r.errorThreshold}');
      case PolicySeverity.informational:
        print('  ℹ️  ${r.metricName.padRight(31)}: $actualStr  (informativo para scope $scopeKey)');
    }
  }
}

// ---------------------------------------------------------------------------
// Architecture Baselines — Evolutionary Governance
// ---------------------------------------------------------------------------

const _baselinesRoot = '.ai/architecture-baselines';

/// Resolves the canonical filesystem path for a scope's baseline JSON file.
class BaselineResolver {
  String resolve(AnalysisScope scope) {
    switch (scope.type) {
      case AnalysisScopeType.monorepo:
        return '$_baselinesRoot/monorepo.metrics.json';

      case AnalysisScopeType.app:
        return '$_baselinesRoot/apps/${scope.appName}.metrics.json';

      case AnalysisScopeType.package:
        return '$_baselinesRoot/packages/${scope.packageName}.metrics.json';

      case AnalysisScopeType.feature:
        return '$_baselinesRoot/features/${scope.appName}/${scope.featureName}.metrics.json';

      case AnalysisScopeType.appsGroup:
        return '$_baselinesRoot/apps/_group.metrics.json';

      case AnalysisScopeType.packagesGroup:
        return '$_baselinesRoot/packages/_group.metrics.json';

      case AnalysisScopeType.unknown:
        final label = scope.label.replaceAll('/', '_');
        return '$_baselinesRoot/unknown/$label.metrics.json';
    }
  }
}

/// Serialises a [ModuleMetrics] snapshot to the baseline JSON format.
class BaselineExporter {
  final BaselineResolver _resolver = BaselineResolver();

  /// Writes the baseline file and returns the path written.
  String export(ModuleMetrics m) {
    final path = _resolver.resolve(m.scope);
    final file = File(path);
    file.parent.createSync(recursive: true);

    final allFunctions = m.allFunctions;
    final ccValues = allFunctions.map((f) => f.cyclomaticComplexity).toList();
    final avgCC = ccValues.isEmpty
        ? 0.0
        : ccValues.reduce((a, b) => a + b) / ccValues.length;
    final maxCC = ccValues.isEmpty ? 0 : ccValues.reduce(max);

    final topCogc = m.cogc.top(5);
    final topNesting = m.nesting.top(5);

    final json = <String, dynamic>{
      'version': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': _scopeLabel(m.scope.type),
      if (m.scope.appName != null) 'app': m.scope.appName,
      if (m.scope.featureName != null) 'feature': m.scope.featureName,
      if (m.scope.packageName != null) 'package': m.scope.packageName,
      'metrics': {
        'cyclomaticComplexity': {
          'average': _round2(avgCC),
          'maximum': maxCC,
        },
        'cognitiveComplexity': {
          'average': _round2(m.cogc.average),
          'maximum': m.cogc.maximum,
        },
        'nestingDepth': {
          'average': _round2(m.nesting.average),
          'maximum': m.nesting.maximum,
        },
        'coupling': {
          'ce': m.efferentCoupling,
          'ca': m.afferentCoupling,
          'instability': _round2(m.instability),
        },
        'abstraction': {
          'a': _round2(m.abstractionRatio),
          'd': _round2(m.mainSequenceDistance),
        },
        'size': {
          'loc': m.totalLoc,
          'classes': m.totalClasses,
          'functions': allFunctions.length,
        },
      },
      'hotspots': {
        'cognitiveComplexity': topCogc
            .map((f) => {'name': f.name, 'score': f.cognitiveScore})
            .toList(),
        'nestingDepth': topNesting
            .map((f) => {'name': f.name, 'score': f.maxDepth})
            .toList(),
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(json));
    return path;
  }

  String _scopeLabel(AnalysisScopeType t) => switch (t) {
        AnalysisScopeType.feature => 'feature',
        AnalysisScopeType.app => 'app',
        AnalysisScopeType.package => 'package',
        AnalysisScopeType.appsGroup => 'appsGroup',
        AnalysisScopeType.packagesGroup => 'packagesGroup',
        AnalysisScopeType.monorepo => 'monorepo',
        AnalysisScopeType.unknown => 'unknown',
      };

  double _round2(double v) => double.parse(v.toStringAsFixed(2));
}

/// A single metric comparison: name, baseline value, current value.
class MetricDelta {
  final String name;
  final num baseline;
  final num current;

  /// Higher = worse for most metrics (CC, CogC, Nesting, Ce, LOC, D).
  /// For Ca, higher = better (more consumers). Pass [higherIsBetter]=true.
  final bool higherIsBetter;

  const MetricDelta({
    required this.name,
    required this.baseline,
    required this.current,
    this.higherIsBetter = false,
  });

  num get delta => current - baseline;
  bool get improved => higherIsBetter ? delta > 0 : delta < 0;
  bool get regressed => higherIsBetter ? delta < 0 : delta > 0;
  bool get unchanged => delta == 0;
}

/// Compares current [ModuleMetrics] against a persisted baseline JSON.
class BaselineComparator {
  final BaselineResolver _resolver = BaselineResolver();

  /// Prints a detailed delta report to stdout.
  /// Returns false (and prints a message) if no baseline exists yet.
  bool compare(ModuleMetrics m) {
    final path = _resolver.resolve(m.scope);
    final file = File(path);
    if (!file.existsSync()) {
      print('');
      print('  ── Comparación con Baseline ─────────────────────────');
      print('  ℹ️  No existe baseline en: $path');
      print('  Ejecuta --export-baseline para crear el primer snapshot.');
      print('');
      return false;
    }

    final Map<String, dynamic> baseline;
    try {
      baseline = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      print('  ⚠️  Baseline corrupto en $path — no se puede comparar.');
      return false;
    }

    final allFunctions = m.allFunctions;
    final ccValues = allFunctions.map((f) => f.cyclomaticComplexity).toList();
    final avgCC = ccValues.isEmpty ? 0.0 : ccValues.reduce((a, b) => a + b) / ccValues.length;
    final maxCC = ccValues.isEmpty ? 0 : ccValues.reduce(max);

    final bMetrics = baseline['metrics'] as Map<String, dynamic>? ?? {};
    final bCC     = bMetrics['cyclomaticComplexity'] as Map<String, dynamic>? ?? {};
    final bCogc   = bMetrics['cognitiveComplexity']  as Map<String, dynamic>? ?? {};
    final bNest   = bMetrics['nestingDepth']          as Map<String, dynamic>? ?? {};
    final bCoupl  = bMetrics['coupling']              as Map<String, dynamic>? ?? {};
    final bAbstr  = bMetrics['abstraction']           as Map<String, dynamic>? ?? {};
    final bSize   = bMetrics['size']                  as Map<String, dynamic>? ?? {};

    final deltas = [
      MetricDelta(name: 'CC máximo',    baseline: (bCC['maximum']   ?? 0) as num, current: maxCC),
      MetricDelta(name: 'CC promedio',  baseline: (bCC['average']   ?? 0.0) as num, current: double.parse(avgCC.toStringAsFixed(2))),
      MetricDelta(name: 'CogC máximo',  baseline: (bCogc['maximum'] ?? 0) as num, current: m.cogc.maximum),
      MetricDelta(name: 'CogC promedio',baseline: (bCogc['average'] ?? 0.0) as num, current: double.parse(m.cogc.average.toStringAsFixed(2))),
      MetricDelta(name: 'Nesting máximo', baseline: (bNest['maximum'] ?? 0) as num, current: m.nesting.maximum),
      MetricDelta(name: 'Ce',           baseline: (bCoupl['ce']     ?? 0) as num, current: m.efferentCoupling),
      MetricDelta(name: 'Ca',           baseline: (bCoupl['ca']     ?? 0) as num, current: m.afferentCoupling, higherIsBetter: true),
      MetricDelta(name: 'Inestabilidad',baseline: (bCoupl['instability'] ?? 0.0) as num, current: double.parse(m.instability.toStringAsFixed(2))),
      MetricDelta(name: 'D (distancia)',baseline: (bAbstr['d']      ?? 0.0) as num, current: double.parse(m.mainSequenceDistance.toStringAsFixed(2))),
      MetricDelta(name: 'LOC',          baseline: (bSize['loc']     ?? 0) as num, current: m.totalLoc),
      MetricDelta(name: 'Clases',       baseline: (bSize['classes'] ?? 0) as num, current: m.totalClasses),
      MetricDelta(name: 'Funciones',    baseline: (bSize['functions'] ?? 0) as num, current: allFunctions.length),
    ];

    final baselineDate = baseline['generatedAt'] as String? ?? '—';
    print('');
    print('  ── Comparación con Baseline ─────────────────────────');
    print('  Baseline : $baselineDate');
    print('');

    for (final d in deltas) {
      _printDelta(d);
    }

    // ── Hotspot diff — CogC ──
    final bHotspots  = baseline['hotspots'] as Map<String, dynamic>? ?? {};
    final bCogcHots  = (bHotspots['cognitiveComplexity'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final bNestHots  = (bHotspots['nestingDepth'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    _printHotspotDiff('CogC', bCogcHots, m.cogc.top(5).map((f) => {'name': f.name, 'score': f.cognitiveScore}).toList());
    _printHotspotDiff('Nesting', bNestHots, m.nesting.top(5).map((f) => {'name': f.name, 'score': f.maxDepth}).toList());

    print('  ────────────────────────────────────────────────────');
    print('');
    return true;
  }

  void _printDelta(MetricDelta d) {
    final bStr = _fmtNum(d.baseline);
    final cStr = _fmtNum(d.current);
    final dStr = d.delta >= 0 ? '+${_fmtNum(d.delta)}' : _fmtNum(d.delta);

    if (d.unchanged) {
      print('  ℹ️  ${d.name.padRight(16)}: $bStr → $cStr  (sin cambios)');
    } else if (d.improved) {
      print('  ✅ ${d.name.padRight(16)}: $bStr → $cStr  ($dStr mejoró)');
    } else {
      print('  ⚠️  ${d.name.padRight(16)}: $bStr → $cStr  ($dStr empeoró)');
    }
  }

  void _printHotspotDiff(
    String metricLabel,
    List<Map<String, dynamic>> before,
    List<Map<String, dynamic>> after,
  ) {
    if (before.isEmpty && after.isEmpty) return;

    // Build name→score maps
    final bMap = {for (final e in before) e['name'] as String: e['score'] as num};
    final aMap = {for (final e in after)  e['name'] as String: e['score'] as num};

    final allNames = {...bMap.keys, ...aMap.keys};
    bool headerPrinted = false;

    for (final name in allNames) {
      final bScore = bMap[name];
      final aScore = aMap[name];
      if (bScore == null || aScore == null) continue; // new or removed — skip
      if (bScore == aScore) continue;

      if (!headerPrinted) {
        print('');
        print('  Hotspots $metricLabel:');
        headerPrinted = true;
      }
      final improved = aScore < bScore;
      final icon = improved ? '✅' : '⚠️ ';
      final verb = improved ? 'mejoró' : 'empeoró';
      print('  $icon $name  $metricLabel: $bScore → $aScore  ($verb)');
    }
  }

  String _fmtNum(num v) => v is double ? v.toStringAsFixed(2) : v.toString();
}

// ---------------------------------------------------------------------------
// Policy Engine — scope-aware governance
// ---------------------------------------------------------------------------

const _defaultPoliciesPath = '.ai/architecture-policies.yaml';

// ── Severity ──────────────────────────────────────────────────────────────

enum PolicySeverity { ok, informational, warning, error }

// ── PolicyRule ────────────────────────────────────────────────────────────

/// A single numeric threshold rule: optional warning/error levels.
/// When both are null the rule is treated as informational-only.
class PolicyRule {
  final String metricName;
  final num? warningThreshold;
  final num? errorThreshold;

  /// When true, higher values are better (e.g. Ca). Not currently exposed in
  /// YAML but kept for forward-compatibility.
  final bool higherIsBetter;

  /// When true the metric is explicitly marked informational in the YAML
  /// (abstraction.distance with mode: informational).
  final bool informationalOnly;

  const PolicyRule({
    required this.metricName,
    this.warningThreshold,
    this.errorThreshold,
    this.higherIsBetter = false,
    this.informationalOnly = false,
  });

  PolicySeverity evaluate(num actual) {
    if (informationalOnly) return PolicySeverity.informational;
    if (errorThreshold != null) {
      final cmp = higherIsBetter
          ? actual < errorThreshold!
          : actual >= errorThreshold!;
      if (cmp) return PolicySeverity.error;
    }
    if (warningThreshold != null) {
      final cmp = higherIsBetter
          ? actual < warningThreshold!
          : actual >= warningThreshold!;
      if (cmp) return PolicySeverity.warning;
    }
    return PolicySeverity.ok;
  }
}

// ── ScopePolicy ────────────────────────────────────────────────────────────

/// All rules applicable to a given scope type.
class ScopePolicy {
  final String scopeLabel;
  final List<PolicyRule> rules;

  const ScopePolicy({required this.scopeLabel, required this.rules});
}

// ── ArchitecturePolicy ─────────────────────────────────────────────────────

enum EnforcementMode { reportOnly, failOnError, failOnRegression }

class ArchitecturePolicy {
  final int version;
  final EnforcementMode enforcement;

  /// scope-label → ScopePolicy
  final Map<String, ScopePolicy> scopes;

  const ArchitecturePolicy({
    required this.version,
    required this.enforcement,
    required this.scopes,
  });

  ScopePolicy? policyFor(AnalysisScopeType type) {
    final key = _scopeKey(type);
    return scopes[key];
  }

  static String _scopeKey(AnalysisScopeType t) => switch (t) {
        AnalysisScopeType.feature => 'feature',
        AnalysisScopeType.app => 'app',
        AnalysisScopeType.package => 'package',
        AnalysisScopeType.monorepo => 'monorepo',
        // Groups: fall back to their child scope key at reporting time
        AnalysisScopeType.appsGroup => 'app',
        AnalysisScopeType.packagesGroup => 'package',
        AnalysisScopeType.unknown => 'monorepo',
      };
}

// ── PolicyEvaluation ──────────────────────────────────────────────────────

/// Result of evaluating one rule against one actual value.
class PolicyEvaluation {
  final PolicyRule rule;
  final num actual;
  final PolicySeverity severity;

  const PolicyEvaluation({
    required this.rule,
    required this.actual,
    required this.severity,
  });

  bool get isOk => severity == PolicySeverity.ok;
}

// ── PolicyLoader ───────────────────────────────────────────────────────────

/// Parses `.ai/architecture-policies.yaml` without external dependencies.
///
/// The YAML dialect supported is intentionally narrow:
///   - indentation-based hierarchy (2 spaces)
///   - `key: value` scalar pairs
///   - no lists, no anchors, no multi-line strings
///
/// Any parse error or missing file falls back silently to built-in defaults.
class PolicyLoader {
  static const _defaultEnforcement = EnforcementMode.reportOnly;

  /// Loads the policy file at [path]. Falls back to defaults if absent/broken.
  /// [warnMissing]: when true, prints a notice if file is missing.
  ArchitecturePolicy load(String path, {bool warnMissing = true}) {
    final file = File(path);
    if (!file.existsSync()) {
      if (warnMissing) {
        print('  ℹ️  No se encontró $path, usando políticas por defecto.');
      }
      return _defaults();
    }

    try {
      final lines = file.readAsLinesSync();
      final doc = _parseYaml(lines);
      return _buildPolicy(doc);
    } catch (_) {
      print('  ⚠️  Error al leer $path — usando políticas por defecto.');
      return _defaults();
    }
  }

  // ── Minimal indented-YAML parser → nested Map<String,dynamic> ─────────────

  Map<String, dynamic> _parseYaml(List<String> lines) {
    // Stack of (indent, map). Top of stack is the current container.
    final stack = <({int indent, Map<String, dynamic> map})>[];
    final root = <String, dynamic>{};
    stack.add((indent: -1, map: root));

    for (final rawLine in lines) {
      final stripped = rawLine.replaceAll('\t', '  ');
      final trimmed = stripped.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final indent = stripped.length - trimmed.length;
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx < 0) continue;

      final key = trimmed.substring(0, colonIdx).trim();
      final rest = trimmed.substring(colonIdx + 1).trim();

      // Pop stack until parent indent < current indent
      while (stack.length > 1 && stack.last.indent >= indent) {
        stack.removeLast();
      }

      final parent = stack.last.map;

      if (rest.isEmpty) {
        // Nested map
        final child = <String, dynamic>{};
        parent[key] = child;
        stack.add((indent: indent, map: child));
      } else {
        // Scalar value
        parent[key] = _parseScalar(rest);
      }
    }

    return root;
  }

  dynamic _parseScalar(String s) {
    if (s == 'true') return true;
    if (s == 'false') return false;
    final n = num.tryParse(s);
    if (n != null) return n;
    // Strip optional inline comment
    final commentIdx = s.indexOf(' #');
    final clean = commentIdx >= 0 ? s.substring(0, commentIdx).trim() : s;
    return clean;
  }

  // ── Policy builder ─────────────────────────────────────────────────────────

  ArchitecturePolicy _buildPolicy(Map<String, dynamic> doc) {
    final enforcement = _parseEnforcement(
        (doc['defaults'] as Map<String, dynamic>?)?['enforcement'] as String?);

    final rawScopes = doc['scopes'] as Map<String, dynamic>? ?? {};
    final scopePolicies = <String, ScopePolicy>{};

    for (final entry in rawScopes.entries) {
      final scopeKey = entry.key;
      final scopeMap = entry.value as Map<String, dynamic>? ?? {};
      scopePolicies[scopeKey] = ScopePolicy(
        scopeLabel: scopeKey,
        rules: _buildRules(scopeMap),
      );
    }

    return ArchitecturePolicy(
      version: (doc['version'] as num?)?.toInt() ?? 1,
      enforcement: enforcement,
      scopes: scopePolicies,
    );
  }

  EnforcementMode _parseEnforcement(String? s) => switch (s) {
        'fail_on_error' => EnforcementMode.failOnError,
        'fail_on_regression' => EnforcementMode.failOnRegression,
        _ => _defaultEnforcement,
      };

  List<PolicyRule> _buildRules(Map<String, dynamic> scopeMap) {
    final rules = <PolicyRule>[];

    // cognitive_complexity.maximum
    _addNumericRule(rules, scopeMap, 'cognitive_complexity', 'maximum',
        'CogC máximo');

    // nesting_depth.maximum
    _addNumericRule(rules, scopeMap, 'nesting_depth', 'maximum',
        'Nesting máximo');

    // cyclomatic_complexity.maximum
    _addNumericRule(rules, scopeMap, 'cyclomatic_complexity', 'maximum',
        'CC máximo');

    // size.loc
    final sizeMap = scopeMap['size'] as Map<String, dynamic>?;
    if (sizeMap != null) {
      _addNumericRuleFromMap(rules, sizeMap['loc'], 'LOC');
    }

    // coupling.ce
    final couplingMap = scopeMap['coupling'] as Map<String, dynamic>?;
    if (couplingMap != null) {
      _addNumericRuleFromMap(rules, couplingMap['ce'], 'Ce (acoplamiento eferente)');
      _addNumericRuleFromMap(rules, couplingMap['instability'], 'Inestabilidad');
    }

    // abstraction.distance — may have mode: informational
    final abstractionMap = scopeMap['abstraction'] as Map<String, dynamic>?;
    if (abstractionMap != null) {
      final distMap = abstractionMap['distance'] as Map<String, dynamic>?;
      if (distMap != null) {
        if (distMap['mode'] == 'informational') {
          rules.add(const PolicyRule(
            metricName: 'D (distancia A/I)',
            informationalOnly: true,
          ));
        } else {
          _addNumericRuleFromMap(rules, distMap, 'D (distancia A/I)');
        }
      }
    }

    return rules;
  }

  void _addNumericRule(
    List<PolicyRule> rules,
    Map<String, dynamic> scopeMap,
    String section,
    String subKey,
    String metricName,
  ) {
    final sec = scopeMap[section] as Map<String, dynamic>?;
    if (sec == null) return;
    final sub = sec[subKey] as Map<String, dynamic>?;
    if (sub == null) return;
    _addNumericRuleFromMap(rules, sub, metricName);
  }

  void _addNumericRuleFromMap(
      List<PolicyRule> rules, dynamic raw, String metricName) {
    if (raw is! Map<String, dynamic>) return;
    final warning = raw['warning'] as num?;
    final error = raw['error'] as num?;
    if (warning == null && error == null) return;
    rules.add(PolicyRule(
      metricName: metricName,
      warningThreshold: warning,
      errorThreshold: error,
    ));
  }

  // ── Built-in defaults (mirrors YAML content) ──────────────────────────────

  ArchitecturePolicy _defaults() {
    return ArchitecturePolicy(
      version: 1,
      enforcement: _defaultEnforcement,
      scopes: {
        'feature': ScopePolicy(scopeLabel: 'feature', rules: [
          const PolicyRule(metricName: 'CogC máximo',     warningThreshold: 20, errorThreshold: 30),
          const PolicyRule(metricName: 'Nesting máximo',  warningThreshold: 4,  errorThreshold: 6),
          const PolicyRule(metricName: 'CC máximo',       warningThreshold: 15, errorThreshold: 25),
          const PolicyRule(metricName: 'LOC',             warningThreshold: 800, errorThreshold: 1200),
          const PolicyRule(metricName: 'D (distancia A/I)', informationalOnly: true),
        ]),
        'app': ScopePolicy(scopeLabel: 'app', rules: [
          const PolicyRule(metricName: 'CogC máximo',     warningThreshold: 25, errorThreshold: 35),
          const PolicyRule(metricName: 'Nesting máximo',  warningThreshold: 5,  errorThreshold: 7),
          const PolicyRule(metricName: 'CC máximo',       warningThreshold: 20, errorThreshold: 30),
          const PolicyRule(metricName: 'Ce (acoplamiento eferente)', warningThreshold: 15, errorThreshold: 25),
          const PolicyRule(metricName: 'D (distancia A/I)', informationalOnly: true),
        ]),
        'package': ScopePolicy(scopeLabel: 'package', rules: [
          const PolicyRule(metricName: 'CogC máximo',     warningThreshold: 15, errorThreshold: 25),
          const PolicyRule(metricName: 'Nesting máximo',  warningThreshold: 4,  errorThreshold: 6),
          const PolicyRule(metricName: 'CC máximo',       warningThreshold: 12, errorThreshold: 20),
          const PolicyRule(metricName: 'Inestabilidad',   warningThreshold: 0.7, errorThreshold: 0.85),
          const PolicyRule(metricName: 'D (distancia A/I)', warningThreshold: 0.35, errorThreshold: 0.50),
        ]),
        'monorepo': ScopePolicy(scopeLabel: 'monorepo', rules: [
          const PolicyRule(metricName: 'CogC máximo',     warningThreshold: 30, errorThreshold: 45),
          const PolicyRule(metricName: 'Nesting máximo',  warningThreshold: 6,  errorThreshold: 8),
          const PolicyRule(metricName: 'CC máximo',       warningThreshold: 25, errorThreshold: 40),
          const PolicyRule(metricName: 'D (distancia A/I)', informationalOnly: true),
        ]),
      },
    );
  }
}

// ── PolicyEngine ───────────────────────────────────────────────────────────

/// Evaluates [ModuleMetrics] against the [ArchitecturePolicy] for its scope
/// and returns ordered [PolicyEvaluation] results.
class PolicyEngine {
  List<PolicyEvaluation> evaluate(
      ModuleMetrics m, ArchitecturePolicy policy) {
    final scopePolicy = policy.policyFor(m.scope.type);
    if (scopePolicy == null) return [];

    final allFunctions = m.allFunctions;
    final ccValues = allFunctions.map((f) => f.cyclomaticComplexity).toList();
    final maxCC = ccValues.isEmpty ? 0 : ccValues.reduce(max);

    // Build metric name → actual value map
    final actuals = <String, num>{
      'CogC máximo': m.cogc.maximum,
      'Nesting máximo': m.nesting.maximum,
      'CC máximo': maxCC,
      'LOC': m.totalLoc,
      'Ce (acoplamiento eferente)': m.efferentCoupling,
      'Inestabilidad': double.parse(m.instability.toStringAsFixed(2)),
      'D (distancia A/I)': double.parse(m.mainSequenceDistance.toStringAsFixed(2)),
    };

    return scopePolicy.rules.map((rule) {
      final actual = actuals[rule.metricName] ?? 0;
      return PolicyEvaluation(
        rule: rule,
        actual: actual,
        severity: rule.evaluate(actual),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------

class _Options {
  final String? path;
  final bool exportBaseline;
  final bool compareBaseline;
  final String policyPath;

  _Options({
    this.path,
    this.exportBaseline = false,
    this.compareBaseline = false,
    this.policyPath = _defaultPoliciesPath,
  });
}

_Options _parseArgs(List<String> args) {
  String? path;
  bool exportBaseline = false;
  bool compareBaseline = false;
  String policyPath = _defaultPoliciesPath;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--path' && i + 1 < args.length) path = args[i + 1];
    if (args[i] == '--export-baseline') exportBaseline = true;
    if (args[i] == '--compare-baseline') compareBaseline = true;
    if (args[i] == '--policy' && i + 1 < args.length) policyPath = args[i + 1];
  }
  return _Options(
    path: path,
    exportBaseline: exportBaseline,
    compareBaseline: compareBaseline,
    policyPath: policyPath,
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);

  final resolver = AnalysisScopeResolver();
  final scope = resolver.resolve(options.path);

  final scanner = DartScanner();
  final parser = DartFileParser();
  final aggregator = MetricsAggregator();
  final reporter = MetricsReporter();
  final exporter = BaselineExporter();
  final comparator = BaselineComparator();
  final policyLoader = PolicyLoader();
  final policyEngine = PolicyEngine();

  // Load policy (prints notice if file missing)
  final policy = policyLoader.load(options.policyPath);

  // ── Grouped scopes (appsGroup / packagesGroup) ──
  if (scope.type == AnalysisScopeType.appsGroup ||
      scope.type == AnalysisScopeType.packagesGroup) {
    final rootDir = Directory(scope.scanRoot);
    if (!rootDir.existsSync()) {
      print('ERROR: directory "${scope.scanRoot}" does not exist.');
      exit(1);
    }

    // Scan the whole project once for Ca
    final allFiles = await scanner.scan(_projectRoot);
    final allMetrics = allFiles.map(parser.parse).toList();

    final subDirs = rootDir
        .listSync(followLinks: false)
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final groupedResults = <ModuleMetrics>[];

    for (final sub in subDirs) {
      final subName = sub.path.replaceAll('\\', '/').split('/').last;
      if (_ignoredDirs.contains(subName)) continue;

      final rawSubPath = '${scope.scanRoot}/$subName';
      final subScope = resolver.resolve(rawSubPath);
      final subFiles = await scanner.scan(rawSubPath);
      final subMetrics = subFiles.map(parser.parse).toList();

      final m = aggregator.compute(
        scope: subScope,
        targetFiles: subMetrics,
        caFiles: allMetrics,
        targetRawFiles: subFiles,
      );
      groupedResults.add(m);
    }

    if (groupedResults.isEmpty) {
      print('No sub-modules found under "${scope.scanRoot}".');
      exit(0);
    }

    reporter.reportGrouped(groupedResults, scope.label, scope.type);
    exit(0);
  }

  // ── Single-scope analysis ──
  final targetFiles = await scanner.scan(scope.scanRoot);
  final targetMetrics = targetFiles.map(parser.parse).toList();

  // Ca search root may differ from scan root (e.g. feature → same app only)
  List<FileMetrics> caMetrics;
  if (scope.caSearchRoot == scope.scanRoot) {
    caMetrics = targetMetrics;
  } else {
    final caFiles = await scanner.scan(scope.caSearchRoot);
    caMetrics = caFiles.map(parser.parse).toList();
  }

  final moduleMetrics = aggregator.compute(
    scope: scope,
    targetFiles: targetMetrics,
    caFiles: caMetrics,
    targetRawFiles: targetFiles,
  );

  // Always print the standard report
  reporter.report(moduleMetrics);

  // ── Policy evaluation (always runs for single-scope) ──
  final evals = policyEngine.evaluate(moduleMetrics, policy);
  reporter.reportPolicy(evals, scope, policy.enforcement);

  // ── Export baseline ──
  if (options.exportBaseline) {
    final written = exporter.export(moduleMetrics);
    print('  ✅ Baseline exportado → $written');
    print('');
  }

  // ── Compare against baseline ──
  if (options.compareBaseline) {
    comparator.compare(moduleMetrics);
  }

  exit(0);
}
