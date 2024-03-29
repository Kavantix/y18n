import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'src/commands/generate_command.dart';
import 'src/commands/watch_command.dart';

void main(List<String> arguments) async {
  Object? returnCode;
  try {
    final runner =
        CommandRunner('y18n', 'Yaml dart internationalisation (i18n) generator')
          ..addCommand(WatchCommand())
          ..addCommand(GenerateCommand());
    returnCode = await runner.run(arguments);
  } on UsageException catch (usage) {
    print(usage);
    exit(1);
  } catch (error, trace) {
    Logger.root.severe('Something went wrong', error, trace);
    print(error);
    print(trace);
    exit(1);
  }
  if (returnCode is int) {
    exit(returnCode);
  } else {
    exit(0);
  }
}
