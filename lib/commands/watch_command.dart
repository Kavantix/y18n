import 'dart:async';

import 'package:args/command_runner.dart';

import '../src/common.dart';
import '../src/main.dart';
import '../src/parse_yaml.dart';
import '../src/result.dart';
import '../src/tree.dart';
import '../src/write_tree.dart';

class WatchCommand extends Command {
  @override
  String get description =>
      'Generate dart source files continuously from a yaml input';

  @override
  String get name => 'watch';

  WatchCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'strings.dart',
      help:
          'How and where to output the result, can either be `stdout` to print it to the console or a filename',
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    final paths = args.rest;
    if (paths.isEmpty) {
      usageException('No input files provided');
    }
    final completer = Completer<void>();
    final sw = Stopwatch();
    watchPaths(paths).listen(
      (paths) {
        try {
          print('Generating for files: $paths');
          sw
            ..reset()
            ..start();
          final result = paths //
              .map(retrieveInputFileContent)
              .bindAll(parseYaml)
              .bindAll(constructTreeFromYaml)
              .map(mergeTrees)
              .map(fixNames)
              .map(writeTreeToBuffer);
          if (result.hasError) {
            switch (result.error!) {
              case Errors.fileNotFound:
                usageException(
                    'File not found at path: ${result.fileNotFoundPath}');
              case Errors.yamlParsingFailed:
                final fileError = result.yamlParsingFailedError;
                print('${fileError.path} contains invalid yaml:');
                print(fileError.error);
                return;
              case Errors.yamlStructureInvalid:
                final message = result.yamlStructureInvalidMessage;
                print(message);
                return;
            }
          }
          outputBuffer(args['output'], result.value!);
          sw.stop();
          print(
            'Generated ${args['output']} in ${sw.elapsed.inMicroseconds / 1000} ms',
          );
        } catch (error) {
          completer.completeError(error);
        }
      },
      onDone: () => completer.complete(),
      onError: (error) => completer.completeError(error),
    );
    await completer.future;
    return 0;
  }
}
