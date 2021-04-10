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

@immutable
class YamlFile {
  //
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

YamlFile constructTreeFromYaml(YamlDocument yaml) {
  return YamlFile();
}

StringBuffer writeYamlFileToBuffer(StringBuffer buffer, YamlFile file) {
  return buffer;
}
