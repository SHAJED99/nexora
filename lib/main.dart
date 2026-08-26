// lib/main.dart — Flutter's default entry point. Real app wiring lives in
// app/main.dart per docs/conventions.md's "Project structure"; this file
// only forwards to it so `flutter run`/`flutter build` work without a
// --target flag.
export 'app/main.dart';
import 'app/main.dart' as app;

Future<void> main() => app.main();
