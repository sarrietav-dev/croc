enum TransferPhase {
  idle,
  preparing,
  waiting,
  transferring,
  canceling,
  completed,
  failed,
  canceled,
}

class SelectedFile {
  const SelectedFile({
    required this.name,
    required this.path,
    required this.size,
  });

  final String name;
  final String path;
  final int size;
}

class ReceivedFile {
  const ReceivedFile({
    required this.name,
    required this.path,
    required this.size,
  });

  factory ReceivedFile.fromJson(Map<String, Object?> json) {
    return ReceivedFile(
      name: json['name']! as String,
      path: json['path']! as String,
      size: (json['size']! as num).toInt(),
    );
  }

  final String name;
  final String path;
  final int size;
}

class TransferProgress {
  const TransferProgress({
    this.fileName = '',
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.fileIndex = 0,
    this.fileCount = 0,
  });

  final String fileName;
  final int bytesDone;
  final int bytesTotal;
  final int fileIndex;
  final int fileCount;

  double get fraction {
    if (bytesTotal <= 0) return 0;
    return (bytesDone / bytesTotal).clamp(0, 1);
  }
}

class RelaySettings {
  const RelaySettings({
    this.address = 'croc.schollz.com:9009',
    this.ports = '9009,9010,9011,9012,9013',
    this.password = 'pass123',
  });

  final String address;
  final String ports;
  final String password;

  RelaySettings copyWith({String? address, String? ports, String? password}) {
    return RelaySettings(
      address: address ?? this.address,
      ports: ports ?? this.ports,
      password: password ?? this.password,
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const suffixes = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var suffix = 0;
  while (value >= 1024 && suffix < suffixes.length - 1) {
    value /= 1024;
    suffix++;
  }
  final digits = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(digits)} ${suffixes[suffix]}';
}
