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

StringBuffer writeYamlFileToBuffer(StringBuffer buffer, Tree tree) {
  tree.children //
      .forEach(_writeNodeToBuffer.apply(buffer));
  return buffer;
}

void _writeNodeToBuffer(StringBuffer buffer, Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      buffer.writeln('${node.name.then(firstLetterUpperCased)}:');
      (node as SubTree)
          .children //
          .forEach(_writeNodeToBuffer.apply(buffer));
      break;
    case NodeTypes.leaf:
      final leaf = node as Leaf;
      buffer.write(leaf.name);
      buffer.write(' = ');
      buffer.write(leaf.value);
      buffer.writeln();
      break;
  }
}

String firstLetterUpperCased(String input) =>
    input.substring(0, 1).toUpperCase() + input.substring(1);

// extension<T, I> on I Function(T) {
extension<I extends Object> on I {
  R then<R>(R Function(I) func) => func(this);
}

extension<T, P1, P2> on T Function(P1, P2) {
  T Function(P2) apply(P1 p1) => (p2) => this(p1, p2);
}
