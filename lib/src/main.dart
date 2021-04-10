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
  Node(this.name);

  final String name;
  NodeTypes get type;
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
    required this.children,
  }) : super(name);

  final List<Node> children;

  @override
  NodeTypes get type => NodeTypes.subtree;
}

@immutable
class Leaf extends Node {
  Leaf({
    required String name,
    required this.value,
  }) : super(name);

  final String value;

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

final _entryToYamlEntry = (MapEntry<dynamic, YamlNode> entry) {
  print(entry.runtimeType);
  return MapEntry(entry.key.value as String, entry.value);
};

Tree constructTreeFromYaml(YamlDocument yaml) {
  final content = yaml.contents;
  if (content is YamlMap) {
    final children = content.nodes.entries //
        .map(_entryToYamlEntry)
        .map(nodeFromYaml)
        .toList();
    return Tree(children);
  }
  // TODO: handle nicely
  throw FallThroughError();
}

Node nodeFromYaml(MapEntry<String, YamlNode> yaml) {
  if (yaml.value is YamlScalar) {
    // TODO: handle non string values nicely
    return Leaf(
      name: yaml.key,
      value: yaml.value.value as String,
    );
  }
  // TODO: handle nicely
  final content = yaml.value as YamlMap;
  final children = content.nodes.entries //
      .map(_entryToYamlEntry)
      .map(nodeFromYaml)
      .toList();
  return SubTree(
    name: yaml.key,
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
      .children
      .forEach(_writeNodeToBuffer.apply(buffer));
  return buffer;
}

void writeImportsToBuffer(StringBuffer buffer) {
  buffer.writeln("import 'package:intl/intl.dart';");
}

void _writeNodeToBuffer(StringBuffer buffer, Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      final subTree = node as SubTree;
      final type = _typeNameForSubtree(subTree);
      buffer.writeln();
      buffer.writeln('class $type {');
      buffer.writeln('  const $type();');
      buffer.writeln();
      subTree.children //
          .where(nodeIsALeaf)
          .map(nodeAsLeaf)
          .forEach(_writeLeafGetterToBuffer.apply(buffer));
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

final _camelCaseRegex = RegExp(r' (.)');
String camelCasedName(String name) =>
    name.replaceAllMapped(_camelCaseRegex, (m) => m.group(1)!.toUpperCase());

void _writeLeafGetterToBuffer(StringBuffer buffer, Leaf leaf) {
  buffer.writeln(
      "  String get ${camelCasedName(leaf.name)} => Intl.message('${leaf.value}');");
}

void _writeSubtreeGetterToBuffer(StringBuffer buffer, SubTree subTree) {
  final type = _typeNameForSubtree(subTree);
  buffer
      .writeln('  $type get ${camelCasedName(subTree.name)} => const $type();');
}

String _typeNameForSubtree(SubTree subTree) =>
    '_${firstLetterUpperCased(camelCasedName(subTree.name))}';

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

extension<T, P1, P2> on T Function(P1, P2) {
  T Function(P2) apply(P1 p1) => (p2) => this(p1, p2);
}
