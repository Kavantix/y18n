import 'dart:io';
import 'dart:math';

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

Result<String> retrieveInputFileContent(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return Result.fileNotFound(path);
  } else {
    return file.readAsStringSync().asResult();
  }
}

enum NodeTypes {
  subtree,
  leaf,
}

abstract class Node {
  Node({
    required this.name,
    required this.parentNames,
  });

  final String name;
  final List<String> parentNames;
  NodeTypes get type;

  bool get isRoot => name == 'Strings';
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
class Leaf extends Node {
  Leaf({
    required String name,
    required List<String> parentNames,
    required this.arguments,
    required this.value,
  }) : super(name: name, parentNames: parentNames);

  final String value;
  final List<String> arguments;

  @override
  NodeTypes get type => NodeTypes.leaf;
}

Result<YamlDocument> parseYaml(String fileContent) {
  final YamlDocument yaml;
  try {
    yaml = loadYamlDocument(fileContent);
  } on Object catch (error) {
    return Result.yamlParsingFailed(error);
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

final _argumentRegex = RegExp(r'\$(\w[a-zA-Z0-9]+)');
Node nodeFromYaml(List<String> parentNames, MapEntry<String, YamlNode> yaml) {
  if (yaml.value is YamlScalar) {
    // TODO: handle non string values nicely
    final value = yaml.value.value as String;
    final arguments = _argumentRegex
        .allMatches(value)
        .map((match) => match.group(1)!)
        .toList();
    return Leaf(
      name: yaml.key,
      parentNames: parentNames,
      value: value,
      arguments: arguments,
    );
  }
  // TODO: handle nicely
  final content = yaml.value as YamlMap;
  final name = yaml.key;
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
    case NodeTypes.leaf:
      return node;
  }
}

int _compareNodes(Node lhs, Node rhs) {
  if (lhs.type == rhs.type) return 0;
  if (lhs.type == NodeTypes.leaf) return -1;
  return 1;
}

StringBuffer writeYamlFileToBuffer(StringBuffer buffer, Tree tree) {
  writeImportsToBuffer(buffer);
  tree
      .then(sortLeafChildrenFirst)
      .then((tree) =>
          SubTree(name: 'Strings', children: tree.children, parentNames: []))
      .then(_writeNodeToBuffer.apply(buffer));
  return buffer;
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
          .forEach(_writeLeafGetterToBuffer.apply(buffer));
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
    case NodeTypes.leaf:
      _writeLeafGetterToBuffer(buffer, node as Leaf);
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

void _writeLeafGetterToBuffer(StringBuffer buffer, Leaf leaf) {
  buffer.writeln();
  buffer.writeln('  /// A translated string like:');
  final lines = leaf.value.split('\n').toList();
  for (final line in lines) {
    buffer.writeln('  /// `$line`');
  }
  final name = camelCasedName(leaf.name);
  if (leaf.arguments.isEmpty) {
    buffer.writeln('  String get ${name} => Intl.message(');
  } else {
    buffer.writeln('  String ${name}({');
    for (final argument in leaf.arguments) {
      buffer.writeln('    required String $argument,');
    }
    buffer.writeln('  }) =>');
    buffer.writeln('      Intl.message(');
  }
  if (lines.length > 1) {
    buffer.writeln("        '''");
    for (final line in lines.take(lines.length - 1)) {
      buffer.writeln(line);
    }
    buffer.write(lines.last);
    buffer.writeln("''',");
  } else {
    buffer.write("        '");
    buffer.write(lines.first);
    buffer.writeln("',");
  }
  final uniqueName = _uniqueTypeNameforNode(leaf);
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

bool nodeIsALeaf(Node node) => node.type == NodeTypes.leaf;
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
