import 'dart:io';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'common.dart';
import 'result.dart';
import 'tree.dart';

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
