import 'package:args/command_runner.dart';
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
    final results = paths //
        .map(retrieveInputFileContent)
        .bind(parseFile);
    if (results.hasError) {
      switch (results.error!) {
        case Errors.fileNotFound:
          usageException('File not found at path: ${results.fileNotFoundPath}');
        case Errors.yamlParsingFailed:
          print('Invalid yaml!');
          print(results.yamlParsingFailedError);
          return 1;
      }
    }
    final buffer = StringBuffer();
    outputBuffer(args['output'], buffer);
    return 1;
  }
}
