import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:yaml_i18n/commands/generate_command.dart';

void main(List<String> arguments) async {
  try {
    final runner =
        CommandRunner('y18n', 'Yaml dart internationalisation (i18n) generator')
          ..addCommand(GenerateCommand());
    await runner.run(arguments);
  } on UsageException catch (usage) {
    print(usage);
  } catch (error, trace) {
    Logger.root.severe('Something went wrong', error, trace);
    rethrow;
  }
}
