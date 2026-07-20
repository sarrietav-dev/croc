import 'croc_engine.dart';
import 'engine_factory_io.dart'
    if (dart.library.html) 'engine_factory_web.dart'
    as platform;

CrocEngine createDefaultCrocEngine() => platform.createPlatformCrocEngine();
