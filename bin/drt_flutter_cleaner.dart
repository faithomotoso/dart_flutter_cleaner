import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

void main(List<String> arguments) async {
  final ArgParser argParser = ArgParser()
    ..addOption("path",
        mandatory: true,
        abbr: "p",
        help:
            "Provide the full path to the root folder e.g. <root folder>/AndroidStudioProjects",
        valueHelp: "path")
    ..addFlag("parallel",
        help:
            "Run the clean command in parallel (not stable and encounters flutter lock and uses more CPU)")
    ..addOption("step",
        mandatory: false,
        help:
            "Number of processes to run in parallel, defaults to 10 (needs the parallel flag alongside)");

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

    Stream<FileSystemEntity> fileStream = rootDir.list(recursive: true);

    Completer streamCompleter = Completer();

    fileStream.listen((v) {
      if (v.absolute.path.contains("pubspec")) {
        flutterDirs.add(v.parent);
      }
    }, onError: (e) {
      stderr.writeln("Error listening to stream: $e");
    }, onDone: () {
      streamCompleter.complete();
    });

    await streamCompleter.future;

    final DateTime startTime = DateTime.now();

    if (argResults.wasParsed("parallel")) {
      int? step;
      if (argResults.wasParsed("step")) {
        step = int.tryParse(argResults["step"]);
      }

      await runInParallel(flutterDirs.toList(), step: step);
    } else {
      await runSequential(flutterDirs);
    }

    stdout.writeln(
        "Cleaned files in ${DateTime.now().difference(startTime).inSeconds} second(s)");
  } catch (e, s) {
    print("OOps: $e, $s");
    // print(s);

    stderr.writeln("Usage: ${argParser.usage}");
  }
}

Future runInParallel(List<Directory> dirs, {int? step}) async {
  step ??= 10;
  int progress = 0;

  while (progress < dirs.length) {
    await Future.wait(dirs
        .getRange(progress, (progress + step - 1).clamp(0, dirs.length - 1))
        .map(runCleanCommand));
    progress += step;
  }
}

Future runSequential(Iterable<Directory> dirs) async {
  for (Directory projDir in dirs) {
    await runCleanCommand(projDir).catchError((e) {
      stdout.writeln("Error cleaning project ${projDir.absolute.path} -> $e");
      return Future.value(true);
    });
  }
}

Future<bool> runCleanCommand(Directory directory) async {
  stdout.writeln("Cleaning ${directory.absolute.path}");

  Process startedProcess = await Process.start(
    "flutter",
    ["clean"],
    workingDirectory: directory.absolute.path,
    runInShell: Platform.isWindows ? true : false,
  );

  startedProcess.stdout.transform(utf8.decoder).listen(stdout.writeln);
  startedProcess.stderr.transform(utf8.decoder).listen(stdout.writeln);

  await startedProcess.exitCode;

  return true;
}
