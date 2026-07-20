import 'staging_directory_io.dart'
    if (dart.library.html) 'staging_directory_web.dart'
    as platform;

Future<String> createStagingDirectory() =>
    platform.createPlatformStagingDirectory();
