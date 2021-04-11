import 'package:args/command_runner.dart';
import '../src/result.dart';

import '../src/main.dart';

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
    final result = paths //
        .map(retrieveInputFileContent)
        .then(parseYaml)
        .map(constructTreeFromYaml)
        .map(sortLeafChildrenFirst)
        .fold(mergeTrees)
        .then(writeYamlFileToBuffer.apply(StringBuffer()));
    if (result.hasError) {
      switch (result.error!) {
        case Errors.fileNotFound:
          usageException('File not found at path: ${result.fileNotFoundPath}');
        case Errors.yamlParsingFailed:
          print('Invalid yaml!');
          print(result.yamlParsingFailedError);
          return 1;
      }
    }
    outputBuffer(args['output'], result.value!);
    return 1;
  }
}
