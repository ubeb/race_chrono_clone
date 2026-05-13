class SessionModel {
  final int? id;
  final int startedAt;
  final int? endedAt;

  SessionModel({
    this.id,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at': startedAt,
      'ended_at': endedAt,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'],
      startedAt: map['started_at'],
      endedAt: map['ended_at'],
    );
  }
}