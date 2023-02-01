import 'package:yaml/yaml.dart';

import 'common.dart';
import 'result.dart';
import 'tree.dart';

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

class _YamlStructureInvalid implements Exception {
  _YamlStructureInvalid(this.parentNames, this.message);

  final List<String> parentNames;
  final String message;
}

Result<Tree> constructTreeFromYaml(YamlDocument yaml) {
  final content = yaml.contents;
  if (content is! YamlMap) {
    return Result.yamlStructureInvalid('Invalid yaml file');
  }
  try {
    final children = content.nodes.entries //
        .map(_entryToYamlEntry)
        .map(nodeFromYaml.apply([]))
        .toList();
    return Tree(children).asResult();
  } on _YamlStructureInvalid catch (error) {
    return Result.yamlStructureInvalid(
      '''
Yaml structure invalid!
> Error at: ${error.parentNames.join(" -> ")}
> ** ${error.message} **''',
    );
  }
}

final _entryToYamlEntry = (MapEntry<dynamic, YamlNode> entry) =>
    MapEntry(entry.key.value as String, entry.value);

Node nodeFromYaml(List<String> parentNames, MapEntry<String, YamlNode> yaml) {
  final yamlValue = yaml.value;
  final name = yaml.key;
  if (yamlValue is YamlScalar) {
    final value = yamlValue.value.toString();
    final arguments = _argumentsFromValue(value);
    return ValueLeaf(
      name: name,
      parentNames: parentNames,
      value: value,
      arguments: arguments,
    );
  }
  if (yamlValue is! YamlMap) {
    throw _YamlStructureInvalid(
      parentNames + [name],
      yamlValue is YamlList
          ? 'Lists are not allowed'
          : 'Only scalars and maps are allowed',
    );
  }
  if (yamlValue.keys.contains('\$plural')) {
    final other = yamlValue['\$plural'].toString();
    return PluralLeaf(
      name: name,
      parentNames: parentNames,
      other: other,
      zero: yamlValue['\$zero']?.toString(),
      one: yamlValue['\$one']?.toString(),
      two: yamlValue['\$two']?.toString(),
      few: yamlValue['\$few']?.toString(),
      many: yamlValue['\$many']?.toString(),
      arguments: _argumentsFromValue(other),
    );
  }
  final content = yaml.value as YamlMap;
  final publicName = content.keys.contains('\$name') //
      ? content['\$name'].toString()
      : null;
  final children = content.nodes.entries //
      .where((e) => e.key.value != '\$name')
      .map(_entryToYamlEntry)
      .map(nodeFromYaml.apply(parentNames + [name]))
      .toList();
  return SubTree(
    name: name,
    parentNames: parentNames,
    children: children,
    publicName: publicName,
  );
}

final _argumentRegex = RegExp(r'\$(\w[a-zA-Z0-9]+)');
Set<String> _argumentsFromValue(String value) => //
    _argumentRegex //
        .allMatches(value)
        .map((match) => match.group(1)!)
        .toSet();
