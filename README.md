## Dart Flutter Cleaner
This cli application helps with running `flutter clean` in dart/flutter projects it finds. 

When running the command, provide the root folder that contains sub-folders with flutter projects
or a folder with the project to clean.

### Running the application
Run with `dart run bin/drt_flutter_cleaner.dart -p <full root folder path>`

Add `--parallel` to run the command in a pseudo-parallel way (still a work in progress and uses more resources but is faster).
Provide an optional `--step <number>` e.g `--step 20` when running in parallel to determine the
number of simultaneous execution per time.