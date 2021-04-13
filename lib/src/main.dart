import 'dart:io';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';
import 'result.dart';

void outputBuffer(String outputOption, StringBuffer buffer) {
  switch (outputOption) {
    case 'stdout':
      return outputBufferToStdOut(buffer);
    default:
      final file = fileForOutputOption(outputOption);
      return outputBufferToFile(file, buffer);
  }
}

void outputBufferToFile(File file, StringBuffer buffer) {
  file.writeAsStringSync(buffer.toString());
}

File fileForOutputOption(String outputOption) {
  final file = File(outputOption);
  file.createSync(recursive: true);
  // TODO: do some more checks.
  return file;
}

void outputBufferToStdOut(StringBuffer buffer) {
  print('Result:');
  print('--------------------------------------------------------------------');
  print(buffer.toString());
  print('--------------------------------------------------------------------');
}

// Result<List<String>> retrieveInputFileContents(List<String> paths) {
//   final contents = <String>[];
//   for (final path in paths) {
//     final content = _retrieveInputFileContent(path);
//     if (content.hasError) return content.cast<List<String>>();
//   }
//   return contents.asResult();
// }

@immutable
class FileContent {
  FileContent({
    required this.path,
    required this.content,
  });
  final String path;
  final String content;
}

Result<FileContent> retrieveInputFileContent(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return Result.fileNotFound(path);
  } else {
    final content = file.readAsStringSync();
    return FileContent(path: path, content: content).asResult();
  }
}

enum NodeTypes {
  subtree,
  valueLeaf,
  pluralLeaf,
}

@immutable
abstract class Node {
  Node({
    required this.name,
    required this.parentNames,
  });

  final String name;
  final List<String> parentNames;
  NodeTypes get type;

  bool get isRoot =>
      name == 'Strings' ||
      parentNames.length == 1 && parentNames.first == 'Strings';
}

@immutable
abstract class Leaf extends Node {
  Leaf({
    required String name,
    required List<String> parentNames,
    required this.arguments,
  }) : super(name: name, parentNames: parentNames);

  final List<String> arguments;
}

@immutable
class Tree {
  Tree(this.children);
  final List<Node> children;
}

@immutable
class SubTree extends Node {
  SubTree({
    required String name,
    required List<String> parentNames,
    required this.children,
  }) : super(name: name, parentNames: parentNames);

  final List<Node> children;

  @override
  NodeTypes get type => NodeTypes.subtree;
}

@immutable
class ValueLeaf extends Leaf {
  ValueLeaf({
    required String name,
    required List<String> parentNames,
    required List<String> arguments,
    required this.value,
  }) : super(name: name, parentNames: parentNames, arguments: arguments);

  final String value;

  @override
  NodeTypes get type => NodeTypes.valueLeaf;
}

@immutable
class PluralLeaf extends Leaf {
  PluralLeaf({
    required String name,
    required List<String> parentNames,
    required List<String> arguments,
    required this.other,
    required this.zero,
    required this.one,
    required this.two,
    required this.few,
    required this.many,
  }) : super(name: name, parentNames: parentNames, arguments: arguments);

  final String other;
  final String? zero;
  final String? one;
  final String? two;
  final String? few;
  final String? many;

  @override
  NodeTypes get type => NodeTypes.pluralLeaf;
}

Result<YamlDocument> parseYaml(FileContent fileContent) {
  final YamlDocument yaml;
  try {
    yaml = loadYamlDocument(fileContent.content);
  } on Object catch (error) {
    return Result.yamlParsingFailed(FileError(
      path: fileContent.path,
      error: error,
    ));
  }
  return yaml.asResult();
}

final _entryToYamlEntry = (MapEntry<dynamic, YamlNode> entry) =>
    MapEntry(entry.key.value as String, entry.value);

Tree constructTreeFromYaml(YamlDocument yaml) {
  final content = yaml.contents;
  if (content is YamlMap) {
    final children = content.nodes.entries //
        .map(_entryToYamlEntry)
        .map(nodeFromYaml.apply([]))
        .toList();
    return Tree(children);
  }
  // TODO: handle nicely
  throw FallThroughError();
}

Tree mergeTrees(Iterable<Tree> trees) =>
    Tree([for (final tree in trees) ...tree.children]);

Node nodeFromYaml(List<String> parentNames, MapEntry<String, YamlNode> yaml) {
  final yamlValue = yaml.value;
  final name = yaml.key;
  if (yamlValue is YamlScalar) {
    // TODO: handle non string values nicely
    final value = yamlValue.value as String;
    final arguments = _argumentsFromValue(value);
    return ValueLeaf(
      name: name,
      parentNames: parentNames,
      value: value,
      arguments: arguments,
    );
  } else if (yamlValue is YamlMap &&
      (yamlValue.keys.first as String).startsWith('\$')) {
    if (yamlValue.keys.contains('\$plural')) {
      final other = yamlValue['\$plural'] as String;
      return PluralLeaf(
        name: name,
        parentNames: parentNames,
        other: other,
        zero: yamlValue['\$zero'] as String?,
        one: yamlValue['\$one'] as String?,
        two: yamlValue['\$two'] as String?,
        few: yamlValue['\$few'] as String?,
        many: yamlValue['\$many'] as String?,
        arguments: _argumentsFromValue(other),
      );
    }
  }
  // TODO: handle nicely
  final content = yaml.value as YamlMap;
  final children = content.nodes.entries //
      .map(_entryToYamlEntry)
      .map(nodeFromYaml.apply(parentNames + [name]))
      .toList();
  return SubTree(
    name: name,
    parentNames: parentNames,
    children: children,
  );
}

final _argumentRegex = RegExp(r'\$(\w[a-zA-Z0-9]+)');
List<String> _argumentsFromValue(String value) => _argumentRegex
    .allMatches(value)
    .map((match) => match.group(1)!)
    .toSet()
    .toList();

Tree sortLeafChildrenFirst(Tree tree) {
  return Tree(
    tree //
        .children
        .map(_sortLeafChildrenFirst)
        .toList(),
  );
}

Node _sortLeafChildrenFirst(Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      final subtree = node as SubTree;
      subtree.children.sort(_compareNodes);
      return subtree;
    case NodeTypes.valueLeaf:
    case NodeTypes.pluralLeaf:
      return node;
  }
}

int _compareNodes(Node lhs, Node rhs) {
  if (lhs.type == rhs.type) return 0;
  if (lhs.type == NodeTypes.valueLeaf) return -1;
  return 1;
}

StringBuffer writeTreeToBuffer(Tree tree) {
  final buffer = StringBuffer();
  writeImportsToBuffer(buffer);
  tree
      .then(sortLeafChildrenFirst)
      .then((tree) => SubTree(
            name: 'Strings',
            children: _childrenWithParentNameForLeafChildren(tree.children,
                parentName: 'Strings'),
            parentNames: [],
          ))
      .then(_writeNodeToBuffer.apply(buffer));
  return buffer;
}

List<Node> _childrenWithParentNameForLeafChildren(List<Node> children,
    {required String parentName}) {
  final newChildren = <Node>[];
  for (final child in children) {
    switch (child.type) {
      case NodeTypes.subtree:
        newChildren.add(child);
        break;
      case NodeTypes.valueLeaf:
        final leaf = child as ValueLeaf;
        newChildren.add(ValueLeaf(
          name: leaf.name,
          value: leaf.value,
          parentNames: [parentName],
          arguments: leaf.arguments,
        ));
        break;
      case NodeTypes.pluralLeaf:
        final leaf = child as PluralLeaf;
        newChildren.add(PluralLeaf(
          name: leaf.name,
          other: leaf.other,
          zero: leaf.zero,
          one: leaf.one,
          two: leaf.two,
          few: leaf.few,
          many: leaf.many,
          parentNames: [parentName],
          arguments: leaf.arguments,
        ));
        break;
    }
  }
  return newChildren;
}

void writeImportsToBuffer(StringBuffer buffer) {
  buffer.writeln("import 'package:flutter/widgets.dart';");
  buffer.writeln("import 'package:intl/intl.dart';");
}

void _writeNodeToBuffer(StringBuffer buffer, Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      final subTree = node as SubTree;
      final type = _uniqueTypeNameforNode(subTree);
      buffer.writeln();
      buffer.writeln('class $type {');
      buffer.writeln('  const $type();');
      if (node.isRoot) {
        _writeInheritedWidgetStaticMethodToBuffer(buffer);
      }
      subTree.children //
          .where(nodeIsALeaf)
          .map(nodeAsLeaf)
          .forEach(_writeLeafToBuffer.apply(buffer));
      buffer.writeln();
      subTree.children //
          .where(nodeIsASubtree)
          .map(nodeAsSubtree)
          .forEach(_writeSubtreeGetterToBuffer.apply(buffer));
      buffer.writeln('}');
      subTree.children //
          .where(nodeIsASubtree)
          .forEach(_writeNodeToBuffer.apply(buffer));
      break;
    case NodeTypes.valueLeaf:
      _writeValueLeafToBuffer(buffer, node as ValueLeaf);
      break;
    case NodeTypes.pluralLeaf:
      _writePluralLeafToBuffer(buffer, node as PluralLeaf);
      break;
  }
}

void _writeLeafToBuffer(StringBuffer buffer, Leaf leaf) {
  switch (leaf.type) {
    case NodeTypes.subtree:
      assert(false, 'Leaf cannot be a subtree');
      break;
    case NodeTypes.valueLeaf:
      _writeValueLeafToBuffer(buffer, leaf as ValueLeaf);
      break;
    case NodeTypes.pluralLeaf:
      _writePluralLeafToBuffer(buffer, leaf as PluralLeaf);
      break;
  }
}

void _writeInheritedWidgetStaticMethodToBuffer(StringBuffer buffer) {
  buffer.writeln('''

  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings)!;
  }''');
}

final _camelCaseRegex = RegExp(r' (.)');
String camelCasedName(String name) =>
    name.replaceAllMapped(_camelCaseRegex, (m) => m.group(1)!.toUpperCase());

void _writePluralLeafToBuffer(StringBuffer buffer, PluralLeaf leaf) {
  buffer.writeln();
  buffer.writeln('  /// A translated plural string like:');
  final lines = leaf.other.split('\n').toList();
  for (final line in lines) {
    buffer.writeln('  /// `$line`');
  }
  _writeArgumentsToBuffer(buffer, leaf, firstArgumentType: 'num');
  buffer.writeln('      Intl.plural(');
  buffer.writeln('        ${leaf.arguments.first},');
  final params = {
    'other': leaf.other,
    'zero': leaf.zero,
    'one': leaf.one,
    'two': leaf.two,
    'few': leaf.few,
    'many': leaf.many,
  };
  for (final param in params.entries) {
    if (param.value == null) continue;
    final lines = param.value!.split('\n').toList();
    _writeLeafLinesToBuffer(buffer, lines, key: param.key);
  }
  final uniqueName = _uniqueLeafNameforNode(leaf, isPrivate: true);
  buffer.writeln("        name: '$uniqueName',");
  if (leaf.arguments.isNotEmpty) {
    buffer.writeln('        args: [');
    for (final argument in leaf.arguments) {
      buffer.writeln('          $argument,');
    }
    buffer.writeln('        ],');
  }
  buffer.writeln('      );');
}

void _writeArgumentsToBuffer(
  StringBuffer buffer,
  Leaf leaf, {
  String firstArgumentType = 'String',
}) {
  final name = camelCasedName(leaf.name);
  buffer.writeln('  String $name({');
  buffer.writeln('    required $firstArgumentType ${leaf.arguments.first},');
  for (final argument in leaf.arguments.skip(1)) {
    buffer.writeln('    required String $argument,');
  }
  buffer.writeln('  }) =>');
  buffer.writeln('      _$name(');
  for (final argument in leaf.arguments) {
    buffer.writeln('        $argument,');
  }
  buffer.writeln('      );');
  buffer.writeln();
  buffer.writeln('  String _$name(');
  buffer.writeln('    $firstArgumentType ${leaf.arguments.first},');
  for (final argument in leaf.arguments.skip(1)) {
    buffer.writeln('    String $argument,');
  }
  buffer.writeln('  ) =>');
}

void _writeLeafLinesToBuffer(StringBuffer buffer, List<String> lines,
    {String? key}) {
  if (lines.length > 1) {
    if (key != null) {
      buffer.writeln("        $key: '''");
    } else {
      buffer.writeln("        '''");
    }
    for (final line in lines.take(lines.length - 1)) {
      buffer.writeln(line);
    }
    buffer.write(lines.last);
    buffer.writeln("''',");
  } else {
    if (key != null) {
      buffer.write("        $key: '");
    } else {
      buffer.write("        '");
    }
    buffer.write(lines.first);
    buffer.writeln("',");
  }
}

void _writeValueLeafToBuffer(StringBuffer buffer, ValueLeaf leaf) {
  buffer.writeln();
  buffer.writeln('  /// A translated string like:');
  final lines = leaf.value.split('\n').toList();
  for (final line in lines) {
    buffer.writeln('  /// `$line`');
  }
  final name = camelCasedName(leaf.name);
  if (leaf.arguments.isEmpty) {
    buffer.writeln('  String get $name => Intl.message(');
  } else {
    _writeArgumentsToBuffer(buffer, leaf);
    buffer.writeln('      Intl.message(');
  }
  _writeLeafLinesToBuffer(buffer, lines);
  final uniqueName =
      _uniqueLeafNameforNode(leaf, isPrivate: leaf.arguments.isNotEmpty);
  buffer.writeln("        name: '$uniqueName',");
  if (leaf.arguments.isNotEmpty) {
    buffer.writeln('        args: [');
    for (final argument in leaf.arguments) {
      buffer.writeln('          $argument,');
    }
    buffer.writeln('        ],');
  }
  buffer.writeln('      );');
}

void _writeSubtreeGetterToBuffer(StringBuffer buffer, SubTree subTree) {
  final type = _uniqueTypeNameforNode(subTree);
  buffer
      .writeln('  $type get ${camelCasedName(subTree.name)} => const $type();');
}

String _uniqueLeafNameforNode(Node node, {required bool isPrivate}) {
  final buffer = StringBuffer(node.isRoot ? '' : '_');
  for (final name in node.parentNames) {
    name //
        .then(camelCasedName)
        .then(firstLetterUpperCased)
        .then(buffer.write);
  }
  if (isPrivate) buffer.write('_');
  buffer.write('_${camelCasedName(node.name)}');
  return buffer.toString();
}

String _uniqueTypeNameforNode(Node node) {
  final buffer = StringBuffer(node.isRoot ? '' : '_');
  for (final name in node.parentNames.followedBy([node.name])) {
    name //
        .then(camelCasedName)
        .then(firstLetterUpperCased)
        .then(buffer.write);
  }
  return buffer.toString();
}

bool nodeIsALeaf(Node node) => node is Leaf;
bool nodeIsASubtree(Node node) => node.type == NodeTypes.subtree;
SubTree nodeAsSubtree(Node node) => node as SubTree;
Leaf nodeAsLeaf(Node node) => node as Leaf;

String firstLetterUpperCased(String input) =>
    input.substring(0, 1).toUpperCase() + input.substring(1);

// extension<T, I> on I Function(T) {
extension<I extends Object> on I {
  R then<R>(R Function(I) func) => func(this);
}

extension Function2ApplyExtension<T, P1, P2> on T Function(P1, P2) {
  T Function(P2) apply(P1 p1) => (p2) => this(p1, p2);
}
