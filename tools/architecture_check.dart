// ignore_for_file: avoid_print
// Architecture Fitness Functions — suizo-argentina monorepo
//
// Run: melos run check:arch
// Or:  dart run tools/architecture_check.dart --path apps/food_menu
//
// Exit code 0 = no errors (warnings alone don't block)
// Exit code 1 = at least one error violation found

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const _projectRoot = '.';

/// Path segments that identify visual UI files (screens, widgets, pages).
const _uiVisualPathSegments = ['/ui/', '/presentation/', '/screens/', '/widgets/'];

/// File suffixes that identify visual UI files.
const _uiVisualFileSuffixes = ['_screen.dart', '_page.dart', '_widget.dart'];

/// Path segments that identify presentation/state-management files.
const _presentationPathSegments = ['/cubit/', '/bloc/'];

/// File suffixes that identify presentation/state-management files.
const _presentationFileSuffixes = ['_cubit.dart', '_bloc.dart'];

/// Patterns that identify Domain-layer files (by path segment).
const _domainPathSegments = ['/domain/'];

/// Patterns that identify Data-layer files (by path segment).
const _dataPathSegments = ['/data/'];

/// Directories to skip entirely.
const _ignoredDirs = ['.dart_tool', 'build', '.git', 'test', '.fvm'];

// ---------------------------------------------------------------------------
// Severity
// ---------------------------------------------------------------------------

enum _Severity { warning, error }

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Violation {
  const _Violation({
    required this.rule,
    required this.severity,
    required this.file,
    required this.line,
    required this.message,
    required this.code,
  });

  final int rule;
  final _Severity severity;
  final String file;
  final int line;
  final String message;
  final String code;
}

class _Options {
  const _Options({this.path});
  final String? path;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final scanRoot = options.path ?? _projectRoot;

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('  Architecture Fitness Check');
  print('═══════════════════════════════════════════════════════════════');
  print('');

  if (options.path != null) {
    print('  Alcance: ${options.path}');
    print('');
  }

  final dartFiles = await _collectDartFiles(scanRoot);
  print('  Archivos analizados: ${dartFiles.length}');
  print('');

  final violations = <_Violation>[];

  for (final file in dartFiles) {
    final path = file.path.replaceAll(r'\', '/');
    final lines = await file.readAsLines();

    // ── Regex-based rules (1–8) ─────────────────────────────────────────────
    _checkRule1(path, lines, violations);
    _checkRule2(path, lines, violations);
    _checkRule3(path, lines, violations);
    _checkRule4(path, lines, violations);
    _checkRule5(path, lines, violations);
    _checkRule6(path, lines, violations);
    _checkRule7(path, lines, violations);
    _checkRule8(path, lines, violations);

    // ── AST-based rules (9–11) ──────────────────────────────────────────────
    // Parse once per file; skip if parsing fails (don't break the entire check).
    CompilationUnit? unit;
    try {
      final result = parseString(
        content: lines.join('\n'),
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
      unit = result.unit;
    } catch (_) {
      // Unparseable file — regex rules already ran, skip AST rules silently.
    }

    if (unit != null) {
      _checkRule9Ast(path, unit, violations);
      _checkRule10(path, unit, violations);
      _checkRule11(path, unit, violations);
      _checkRule12(path, unit, violations);
    }
  }

  _printResults(violations);

  final hasErrors = violations.any((v) => v.severity == _Severity.error);
  exit(hasErrors ? 1 : 0);
}

// ---------------------------------------------------------------------------
// Rules 1–8 — regex / string-based (unchanged, now tagged as error)
// ---------------------------------------------------------------------------

/// Rule 1: UI no puede importar desde /data/
void _checkRule1(String path, List<String> lines, List<_Violation> out) {
  if (!_isUiOrPresentationFile(path)) return;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!_isImport(line)) continue;
    final importPath = line.replaceAll("'", '"').split('"').elementAtOrNull(1) ?? '';
    if (importPath.isEmpty) continue;
    if ((importPath.contains('/features/') || importPath.contains('/core/')) &&
        importPath.contains('/data/') &&
        !importPath.contains('/ui/data/')) {
      out.add(_Violation(
        rule: 1,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'UI importa desde capa Data',
        code: line.trim(),
      ));
    } else if (importPath.contains('_datasource') ||
        importPath.contains('_repository_impl') ||
        importPath.contains('_dto')) {
      out.add(_Violation(
        rule: 1,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'UI importa desde capa Data',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 2: Domain no puede importar desde /data/ ni /ui/
void _checkRule2(String path, List<String> lines, List<_Violation> out) {
  if (!_isDomainFile(path)) return;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!_isImport(line)) continue;
    if (line.contains('/data/') || line.contains('/ui/') || line.contains('/presentation/')) {
      out.add(_Violation(
        rule: 2,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'Domain importa desde Data o UI',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 3: Data no puede importar desde /ui/ ni /presentation/
void _checkRule3(String path, List<String> lines, List<_Violation> out) {
  if (!_isDataFile(path)) return;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!_isImport(line)) continue;
    if (line.contains('/ui/') || line.contains('/presentation/') || line.contains('/screens/')) {
      out.add(_Violation(
        rule: 3,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'Data importa desde capa UI',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 4: Clases con sufijo Dto solo pueden existir dentro de /data/
void _checkRule4(String path, List<String> lines, List<_Violation> out) {
  if (_isDataFile(path)) return;
  final normalized = path.replaceAll(r'\', '/');
  if (normalized.contains('/packages/core_network/') ||
      normalized.contains('/packages/infrastructure/')) return;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp(r'\bclass\s+\w+Dto\b').hasMatch(line)) {
      out.add(_Violation(
        rule: 4,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'Clase DTO definida fuera de /data/',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 5: RepositoryImpl no puede ser importado desde UI
void _checkRule5(String path, List<String> lines, List<_Violation> out) {
  if (!_isUiOrPresentationFile(path)) return;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!_isImport(line)) continue;
    if (line.contains('_repository_impl') || line.contains('RepositoryImpl')) {
      out.add(_Violation(
        rule: 5,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'UI importa RepositoryImpl',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 6: sl.get<> prohibido en UI/Bloc/Cubit/Screen/Widget
void _checkRule6(String path, List<String> lines, List<_Violation> out) {
  if (!_isUiOrPresentationFile(path)) return;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    if (RegExp(r'\bsl\.get<').hasMatch(line) || RegExp(r'\bsl\.call<').hasMatch(line)) {
      out.add(_Violation(
        rule: 6,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'sl.get<>() usado en capa UI/Bloc — inyectar por constructor',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 7: registerLazySingleton con Bloc o Cubit
void _checkRule7(String path, List<String> lines, List<_Violation> out) {
  if (!path.contains('injection_container') &&
      !path.contains('_di.dart') &&
      !path.contains('setup.dart') &&
      !path.contains('_module.dart')) return;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    if (line.contains('registerLazySingleton') &&
        (RegExp(r'\)\s*=>\s*\w+(Bloc|Cubit)\b').hasMatch(line) ||
            RegExp(r'\w+(Bloc|Cubit)\b.*\)').hasMatch(line) &&
                line.contains('registerLazySingleton'))) {
      out.add(_Violation(
        rule: 7,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'Bloc/Cubit registrado con registerLazySingleton — usar registerFactory',
        code: line.trim(),
      ));
    }
  }
}

/// Rule 8: Either<L, R> con type parameters libres en Domain o Data
void _checkRule8(String path, List<String> lines, List<_Violation> out) {
  if (!_isDomainFile(path) && !_isDataFile(path)) return;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    if (RegExp(r'Either<[A-Z],\s*[A-Z]>').hasMatch(line)) {
      out.add(_Violation(
        rule: 8,
        severity: _Severity.error,
        file: path,
        line: i + 1,
        message: 'Either<L, R> con genéricos libres — usar Either<XxxFailure, T> concreto',
        code: line.trim(),
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// Rule 9 — Excessive private Widget builders (AST)
// ---------------------------------------------------------------------------

/// Rule 9: Detectar pseudo-componentización mediante múltiples _buildX() Widget methods.
///
/// Warning (not error) — heurística de mantenibilidad UI, no viola Clean Architecture.
/// Threshold: >= 4 métodos _buildX en el mismo archivo.
/// Excluye: build(), _buildGap, _buildSpacer, _buildDivider.
void _checkRule9Ast(String path, CompilationUnit unit, List<_Violation> out) {
  if (!_isUiVisualFile(path)) return;

  final visitor = _PrivateWidgetBuilderVisitor(path);
  unit.visitChildren(visitor);

  if (visitor.methods.length >= 4) {
    out.add(_Violation(
      rule: 9,
      severity: _Severity.warning,
      file: path,
      line: visitor.firstLine,
      message: 'Excessive private Widget builders (${visitor.methods.length}) — considerar extraer widgets reales',
      code: visitor.methods.join(', '),
    ));
  }
}

class _PrivateWidgetBuilderVisitor extends RecursiveAstVisitor<void> {
  _PrivateWidgetBuilderVisitor(this.path);

  final String path;
  final List<String> methods = [];
  int firstLine = 1;

  static const _ignoredHelpers = {'_buildGap', '_buildSpacer', '_buildDivider'};

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;

    // Must be private, start with _build, not be 'build' itself
    if (!name.startsWith('_build')) {
      super.visitMethodDeclaration(node);
      return;
    }
    if (_ignoredHelpers.contains(name)) {
      super.visitMethodDeclaration(node);
      return;
    }

    // Return type must be Widget (or Widget?)
    final returnType = node.returnType?.toSource() ?? '';
    if (!returnType.startsWith('Widget')) {
      super.visitMethodDeclaration(node);
      return;
    }

    // Record real line number of the first matching method
    if (methods.isEmpty) {
      firstLine = _offsetToLine(path, node.offset);
    }
    methods.add(name);
    super.visitMethodDeclaration(node);
  }
}

// ---------------------------------------------------------------------------
// Rule 10 — BuildContext inside Cubit/Bloc (AST)
// ---------------------------------------------------------------------------

/// Rule 10: BuildContext stored as field inside a Cubit or Bloc class.
///
/// Error — BuildContext must never be retained in a Cubit or Bloc.
/// This causes memory leaks and couples business logic to the widget tree.
void _checkRule10(String path, CompilationUnit unit, List<_Violation> out) {
  final visitor = _BuildContextInBlocVisitor(path, out);
  unit.visitChildren(visitor);
}

class _BuildContextInBlocVisitor extends RecursiveAstVisitor<void> {
  final String path;
  final List<_Violation> out;

  _BuildContextInBlocVisitor(this.path, this.out);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isBlocOrCubit(node)) {
      super.visitClassDeclaration(node);
      return;
    }

    // Scan all field declarations inside the class body
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final typeSource = member.fields.type?.toSource() ?? '';
        if (_isBuildContextType(typeSource)) {
          final fieldNames =
              member.fields.variables.map((v) => v.name.lexeme).join(', ');
          final lineInfo = member.fields.variables.first.name.offset;
          out.add(_Violation(
            rule: 10,
            severity: _Severity.error,
            file: path,
            line: _offsetToLine(path, lineInfo),
            message:
                'BuildContext almacenado como field en ${node.name.lexeme} — '
                'nunca retener BuildContext en Cubit/Bloc',
            code: member.toSource().trim(),
          ));
        }
      }
    }

    super.visitClassDeclaration(node);
  }

  bool _isBlocOrCubit(ClassDeclaration node) {
    final name = node.name.lexeme;
    if (name.endsWith('Cubit') || name.endsWith('Bloc')) return true;

    // Also check superclass
    final superclass = node.extendsClause?.superclass.name2.lexeme ?? '';
    if (superclass == 'Cubit' || superclass == 'Bloc') return true;
    if (superclass.endsWith('Cubit') || superclass.endsWith('Bloc')) return true;

    return false;
  }

  bool _isBuildContextType(String type) {
    // Matches: BuildContext, BuildContext?, BuildContext _ctx, etc.
    return type == 'BuildContext' || type == 'BuildContext?';
  }
}

// ---------------------------------------------------------------------------
// Rule 11 — Navigator used outside UI layer (AST)
// ---------------------------------------------------------------------------

/// Rule 11: Navigator.of / push / pop / pushNamed / popUntil called outside UI.
///
/// Error — navigation must be triggered from UI (visual) layer only.
/// Domain, Data, Cubit and Bloc must not hold references to Navigator.
void _checkRule11(String path, CompilationUnit unit, List<_Violation> out) {
  // Navigator is allowed in visual UI files only
  if (_isUiVisualFile(path)) return;

  // Only flag layers that clearly should NOT use Navigator
  final isForbiddenLayer = _isDomainFile(path) ||
      _isDataFile(path) ||
      _isPresentationFile(path);

  if (!isForbiddenLayer) return;

  final visitor = _NavigatorUsageVisitor(path, out);
  unit.visitChildren(visitor);
}

const _navigatorMethods = {
  'of',
  'push',
  'pop',
  'pushNamed',
  'pushReplacement',
  'pushReplacementNamed',
  'pushAndRemoveUntil',
  'popUntil',
  'maybePop',
};

class _NavigatorUsageVisitor extends RecursiveAstVisitor<void> {
  _NavigatorUsageVisitor(this.path, this.out);

  final String path;
  final List<_Violation> out;

  /// Local variable names that hold a Navigator reference.
  /// e.g.  final nav = Navigator.of(context);
  final Set<String> _navigatorLocals = {};

  // ── Direct: Navigator.push(...) / Navigator.of(...) ──────────────────────

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? '';
    final methodName = node.methodName.name;

    // Direct: Navigator.xxx(...)
    if (target == 'Navigator' && _navigatorMethods.contains(methodName)) {
      _report(node, 'Navigator.$methodName()');
    }

    // Indirect: nav.push(...) where nav was assigned Navigator.of(context)
    if (_navigatorLocals.contains(target) && _navigatorMethods.contains(methodName)) {
      _report(node, '$target.$methodName() [Navigator indirecto]');
    }

    super.visitMethodInvocation(node);
  }

  // ── Capture: final nav = Navigator.of(context) ───────────────────────────

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is MethodInvocation) {
      final target = initializer.target?.toSource() ?? '';
      final method = initializer.methodName.name;
      if (target == 'Navigator' && method == 'of') {
        _navigatorLocals.add(node.name.lexeme);
      }
    }
    super.visitVariableDeclaration(node);
  }

  // ── Also capture assignments: nav = Navigator.of(context) ────────────────

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final rhs = node.rightHandSide;
    if (rhs is MethodInvocation) {
      final target = rhs.target?.toSource() ?? '';
      final method = rhs.methodName.name;
      if (target == 'Navigator' && method == 'of') {
        final lhs = node.leftHandSide;
        if (lhs is SimpleIdentifier) {
          _navigatorLocals.add(lhs.name);
        }
      }
    }
    super.visitAssignmentExpression(node);
  }

  void _report(AstNode node, String label) {
    out.add(_Violation(
      rule: 11,
      severity: _Severity.error,
      file: path,
      line: _offsetToLine(path, node.offset),
      message: '$label usado fuera de la capa UI — '
          'mover lógica de navegación a la capa de presentación',
      code: node.toSource().trim(),
    ));
  }
}

// ---------------------------------------------------------------------------
// Rule 12 — Possible Entity Trap / Generic Component Naming (AST)
// ---------------------------------------------------------------------------

/// Rule 12: Classes named with generic, entity-centric suffixes that often
/// signal an "Entity Trap" (Mark Richards / Software Architecture Fundamentals).
///
/// Warning — does not block CI.
/// Applies to code under /features/, /domain/, /application/, /services/, /usecases/.
/// Excludes well-known Flutter framework classes and generated files.
void _checkRule12(String path, CompilationUnit unit, List<_Violation> out) {
  if (!_isEntityTrapScope(path)) return;

  final visitor = _EntityTrapVisitor(path, out);
  unit.visitChildren(visitor);
}

/// Path scopes where entity-trap naming is meaningful to flag.
bool _isEntityTrapScope(String path) =>
    path.contains('/features/') ||
    path.contains('/domain/') ||
    path.contains('/application/') ||
    path.contains('/services/') ||
    path.contains('/usecases/');

/// Generic suffixes that often indicate a component built around an entity
/// rather than a clearly scoped business action.
const _entityTrapSuffixes = {
  'Manager',
  'Supervisor',
  'Processor',
  'Handler',
  'Service',
  'Helper',
  'Util',
  'Utils',
  'Controller',
};

/// Flutter / Dart framework classes whose names end in a flagged suffix but
/// are completely legitimate — skip any class that IS or EXTENDS one of these.
const _entityTrapAllowlist = {
  'TextEditingController',
  'ScrollController',
  'AnimationController',
  'TabController',
  'PageController',
  'StreamController',
  'ChangeNotifier',
  'ValueNotifier',
};

class _EntityTrapVisitor extends RecursiveAstVisitor<void> {
  _EntityTrapVisitor(this.path, this.out);

  final String path;
  final List<_Violation> out;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;

    // Skip allowlisted framework classes by name
    if (_entityTrapAllowlist.contains(name)) {
      super.visitClassDeclaration(node);
      return;
    }

    // Skip classes that directly extend an allowlisted framework class
    final superclass = node.extendsClause?.superclass.name2.lexeme ?? '';
    if (_entityTrapAllowlist.contains(superclass)) {
      super.visitClassDeclaration(node);
      return;
    }

    // Check if the class name ends with a flagged suffix
    final matchedSuffix = _entityTrapSuffixes.firstWhere(
      (suffix) => name.endsWith(suffix) && name != suffix,
      orElse: () => '',
    );

    if (matchedSuffix.isNotEmpty) {
      out.add(_Violation(
        rule: 12,
        severity: _Severity.warning,
        file: path,
        line: _offsetToLine(path, node.offset),
        message: 'Possible Entity Trap: "$name" usa sufijo genérico "$matchedSuffix" — '
            'preferir nombres orientados a acción/flujo: ValidateOrder, SubmitOrder, TrackGuide…',
        code: 'class $name',
      ));
    }

    super.visitClassDeclaration(node);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Visual UI layer: screens, pages, widgets, /ui/, /presentation/.
bool _isUiVisualFile(String path) =>
    _uiVisualPathSegments.any(path.contains) ||
    _uiVisualFileSuffixes.any(path.endsWith);

/// Presentation / state-management layer: cubits, blocs.
bool _isPresentationFile(String path) =>
    _presentationPathSegments.any(path.contains) ||
    _presentationFileSuffixes.any(path.endsWith);

/// Combined UI check: visual OR presentation (used by rules that forbid Data imports in either).
bool _isUiOrPresentationFile(String path) =>
    _isUiVisualFile(path) || _isPresentationFile(path);

bool _isDomainFile(String path) => _domainPathSegments.any(path.contains);
bool _isDataFile(String path) => _dataPathSegments.any(path.contains);
bool _isImport(String line) => line.trimLeft().startsWith('import ');

/// Approximate line number from a character offset.
/// Reads the file synchronously; caches nothing (called rarely).
int _offsetToLine(String path, int offset) {
  try {
    final content = File(path).readAsStringSync();
    int line = 1;
    for (int i = 0; i < offset && i < content.length; i++) {
      if (content[i] == '\n') line++;
    }
    return line;
  } catch (_) {
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

_Options _parseArgs(List<String> args) {
  String? path;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--path') {
      if (i + 1 >= args.length) _failUsage('Falta valor para --path');
      path = args[++i];
      continue;
    }
    if (arg.startsWith('--path=')) {
      path = arg.substring('--path='.length);
      continue;
    }
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
    _failUsage('Argumento desconocido: $arg');
  }

  if (path == null) return const _Options();

  final normalized = path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty) _failUsage('El valor de --path no puede ser vacío');

  final directory = Directory(normalized);
  if (!directory.existsSync()) {
    stderr.writeln('❌ Path no encontrado: $normalized');
    exit(2);
  }

  return _Options(path: normalized);
}

Never _failUsage(String message) {
  stderr.writeln('❌ $message');
  _printUsage(stderr);
  exit(64);
}

void _printUsage([IOSink? sink]) {
  (sink ?? stdout).writeln('Uso: dart run tools/architecture_check.dart [--path <directorio>]');
}

// ---------------------------------------------------------------------------
// File collection
// ---------------------------------------------------------------------------

Future<List<File>> _collectDartFiles(String root) async {
  final files = <File>[];
  await _walkDir(Directory(root), files);
  return files;
}

Future<void> _walkDir(Directory dir, List<File> files) async {
  List<FileSystemEntity> entries;
  try {
    entries = await dir.list(followLinks: false).toList();
  } catch (_) {
    return;
  }

  for (final entity in entries) {
    final normalized = entity.path.replaceAll(r'\', '/');
    if (entity is Directory) {
      if (_ignoredDirs.any((seg) =>
          normalized.contains('/$seg') || normalized.contains('\\$seg'))) continue;
      await _walkDir(entity, files);
    } else if (entity is File) {
      if (!entity.path.endsWith('.dart')) continue;
      if (_ignoredDirs.any((seg) =>
          normalized.contains('/$seg') || normalized.contains('\\$seg'))) continue;
      if (normalized.endsWith('.g.dart') || normalized.endsWith('.freezed.dart')) continue;
      files.add(entity);
    }
  }
}

// ---------------------------------------------------------------------------
// Reporter
// ---------------------------------------------------------------------------

void _printResults(List<_Violation> violations) {
  final ruleDescriptions = {
    1: 'Regla 1  — UI importa desde Data',
    2: 'Regla 2  — Domain importa desde Data o UI',
    3: 'Regla 3  — Data importa desde UI',
    4: 'Regla 4  — DTO definido fuera de /data/',
    5: 'Regla 5  — RepositoryImpl importado en UI',
    6: 'Regla 6  — sl.get<>() en UI/Bloc/Screen/Widget',
    7: 'Regla 7  — Bloc/Cubit registrado como LazySingleton',
    8: 'Regla 8  — Either<L, R> con genéricos libres',
    9: 'Regla 9  — Excessive private Widget builders',
    10: 'Regla 10 — BuildContext almacenado en Cubit/Bloc',
    11: 'Regla 11 — Navigator usado fuera de la capa UI',
    12: 'Regla 12 — Possible Entity Trap / Generic Component Naming',
  };

  final errors = violations.where((v) => v.severity == _Severity.error).toList();
  final warnings = violations.where((v) => v.severity == _Severity.warning).toList();

  if (violations.isEmpty) {
    print('  ✅  Sin violaciones arquitectónicas detectadas.');
    print('');
    return;
  }

  // Group by rule, preserve severity order (errors first)
  final byRule = <int, List<_Violation>>{};
  for (final v in violations) {
    byRule.putIfAbsent(v.rule, () => []).add(v);
  }

  for (final ruleId in byRule.keys.toList()..sort()) {
    final ruleViolations = byRule[ruleId]!;
    final isError = ruleViolations.first.severity == _Severity.error;
    final icon = isError ? '❌' : '⚠️ ';
    print('  $icon ${ruleDescriptions[ruleId] ?? 'Regla $ruleId'} (${ruleViolations.length})');
    for (final v in ruleViolations) {
      print('       ${_relativePath(v.file)}:${v.line}');
      print('       → ${v.code}');
    }
    print('');
  }

  print('  Total errores   : ${errors.length}');
  print('  Total warnings  : ${warnings.length}');
  print('');

  if (errors.isNotEmpty) {
    print('  ❌  Violations arquitectónicas encontradas. Exit code 1.');
  } else {
    print('  ⚠️   Solo warnings — no bloquea CI. Exit code 0.');
  }
  print('');
}

String _relativePath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final marker = 'suizo-argentina/';
  final idx = normalized.indexOf(marker);
  return idx >= 0 ? normalized.substring(idx + marker.length) : normalized;
}
