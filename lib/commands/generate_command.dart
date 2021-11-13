import 'package:args/command_runner.dart';

import '../src/common.dart';
import '../src/main.dart';
import '../src/parse_yaml.dart';
import '../src/result.dart';
import '../src/tree.dart';
import '../src/write_tree.dart';

class GenerateCommand extends Command {
  @override
  String get description => 'Generate dart source files from a yaml input';

  @override
  String get name => 'generate';

  GenerateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'stdout',
      help:
          'How and where to output the result, can either be `stdout` to print it to the console or a filename',
    );
  }

  @override
  int run() {
    final args = argResults!;
    final paths = args.rest;
    if (paths.isEmpty) {
      usageException('No input files provided');
    }
    return paths //
        .map(retrieveInputFileContent)
        .bindAll(parseYaml)
        .bindAll(constructTreeFromYaml)
        .map(mergeTrees)
        .map(fixNames)
        .map(writeTreeToBuffer)
        .match(
          value: (value) {
            outputBuffer(args['output'], value);
            return 0;
          },
          failure: (failure) => failure.match(
            fileNotFound: (filePath) =>
                usageException('File not found at path: ${filePath.value}'),
            yamlParsingFailed: (fileError) {
              print('${fileError.path} contains invalid yaml:');
              print(fileError.error);
              return 1;
            },
            yamlStructureInvalid: (explanation) {
              print(explanation.value);
              return 1;
            },
          ),
        );
  }
}
