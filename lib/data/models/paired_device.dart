enum PairedDeviceStatus {
  connected,
  waiting,
  disconnected,
}

class PairedDevice {
  final String id;
  final String name;
  final String ipAddress;
  final DateTime connectedAt;
  final DateTime lastPingAt;
  final PairedDeviceStatus status;

  PairedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.connectedAt,
    required this.lastPingAt,
    this.status = PairedDeviceStatus.connected,
  });

  bool get isConnected => status == PairedDeviceStatus.connected;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'connectedAt': connectedAt.toIso8601String(),
      'lastPingAt': lastPingAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory PairedDevice.fromMap(Map<String, dynamic> map) {
    return PairedDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Mobile Scanner',
      ipAddress: map['ipAddress'] as String? ?? 'Unknown IP',
      connectedAt: DateTime.tryParse(map['connectedAt'] as String? ?? '') ?? DateTime.now(),
      lastPingAt: DateTime.tryParse(map['lastPingAt'] as String? ?? '') ?? DateTime.now(),
      status: PairedDeviceStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PairedDeviceStatus.connected,
      ),
    );
  }

  PairedDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    DateTime? connectedAt,
    DateTime? lastPingAt,
    PairedDeviceStatus? status,
  }) {
    return PairedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      connectedAt: connectedAt ?? this.connectedAt,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      status: status ?? this.status,
    );
  }
}
