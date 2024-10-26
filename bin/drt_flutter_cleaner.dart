import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';

void main(List<String> arguments) async {
  final ArgParser argParser = ArgParser()
    ..addOption("path",
        mandatory: true,
        abbr: "p",
        help:
            "Provide the full path to the root folder e.g. <root folder>/AndroidStudioProjects",
        valueHelp: "path");

  try {
    ArgResults argResults = argParser.parse(arguments);

    // The root path would contain folder(s) in it
    final String rootPath = argResults["path"];
    Set<Directory> flutterDirs = HashSet(
      equals: (d1, d2) => d1.absolute.path.compareTo(d2.absolute.path) == 0,
      hashCode: (d) => Object.hashAll(
        [d.absolute.path],
      ),
    );

    final Directory rootDir = Directory(rootPath);
    List<FileSystemEntity> rootEntities =
        await rootDir.list(recursive: true).toList();

    flutterDirs.addAll(rootEntities
        .whereType<File>()
        .where((f) => f.absolute.path.contains("pubspec"))
        .map((e) => e.parent));

    final DateTime startTime = DateTime.now();
    for (Directory projDir in flutterDirs) {
      // Run flutter clean
      try {
        await runCleanCommand(projDir).catchError((e) {
          stdout
              .writeln("Error cleaning project ${projDir.absolute.path} -> $e");
          return Future.value(true);
        });
      } on Exception catch (e) {
        stderr.writeln("Error cleaning ${projDir.absolute.path}");
      }
    }

    stdout.writeln("Cleaned files in ${DateTime.now().difference(startTime).inSeconds} second(s)");
  } catch (e, s) {
    print("OOps: $e");
    // print(s);

    stderr.writeln("Usage: ${argParser.usage}");
  }
}

Future<bool> runCleanCommand(Directory directory) async {
  stdout.writeln("Cleaning ${directory.absolute.path}");

  Process startedProcess = await Process.start(
    "flutter",
    ["clean"],
    workingDirectory: directory.absolute.path,
    runInShell: true,
  );

  // This `prints` the outputs of the startedProcess
  await stdout.addStream(startedProcess.stdout);
  await stdout.addStream(startedProcess.stderr);

  stdout.writeln("");

  return true;
}
