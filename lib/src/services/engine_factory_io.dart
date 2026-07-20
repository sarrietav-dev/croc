import 'dart:io';

import 'croc_engine.dart';
import 'desktop_croc_engine.dart';

CrocEngine createPlatformCrocEngine() =>
    Platform.isAndroid ? NativeCrocEngine() : DesktopCrocEngine();
