// lib/models/models.dart

// ─── USER ─────────────────────────────────────────────────────────────────────
class User {
  final int id;
  final String email;
  final String? phone;
  final String token;
  final String status;
  final String? message;
  final String verified;
  final String createdAt;
  final String role;
  final String? fullName;
  final String? gender;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.token,
    required this.status,
    this.message,
    required this.verified,
    required this.createdAt,
    required this.role,
    this.fullName,
    this.gender,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        email: json['email'] ?? '',
        phone: json['phone'],
        token: json['token'] ?? '',
        status: json['status'] ?? '',
        message: json['message'],
        verified: json['verified']?.toString() ?? 'false',
        createdAt: json['createdAt'] ?? '',
        role: json['role'] ?? '',
        fullName: json['fullName'],
        gender: json['gender'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'token': token,
        'status': status,
        'message': message,
        'verified': verified,
        'createdAt': createdAt,
        'role': role,
        'fullName': fullName,
        'gender': gender,
      };
}

// ─── ELDERLY PROFILE ──────────────────────────────────────────────────────────
class ElderlyProfileRequest {
  final String dateOfBirth;
  final String? healthNotes;
  final String name;
  final String? preferredLanguage;
  final String? speakingSpeed;
  final int? roomId;

  ElderlyProfileRequest({
    required this.dateOfBirth,
    this.healthNotes,
    required this.name,
    this.preferredLanguage,
    this.speakingSpeed,
    this.roomId,
  });

  Map<String, dynamic> toJson() => {
        'dateOfBirth': dateOfBirth,
        'name': name,
        if (healthNotes != null) 'healthNotes': healthNotes,
        if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        if (speakingSpeed != null) 'speakingSpeed': speakingSpeed,
        if (roomId != null) 'roomId': roomId,
      };
}

class ElderlyProfile {
  final int id;
  final String name;
  final String? dateOfBirth;
  final String? healthNotes;
  final String? preferredLanguage;
  final String? speakingSpeed;
  final int? roomId;

  ElderlyProfile({
    required this.id,
    required this.name,
    this.dateOfBirth,
    this.healthNotes,
    this.preferredLanguage,
    this.speakingSpeed,
    this.roomId,
  });

  factory ElderlyProfile.fromJson(Map<String, dynamic> json) => ElderlyProfile(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        dateOfBirth: json['dateOfBirth'],
        healthNotes: json['healthNotes'],
        preferredLanguage: json['preferredLanguage'],
        speakingSpeed: json['speakingSpeed'],
        roomId: json['roomId'],
      );
}

// ─── REMINDER ─────────────────────────────────────────────────────────────────
class Reminder {
  final int id;
  final int elderlyId;
  final String? elderlyName;
  final int? accountId;
  final int? caregiverId;
  final String? caregiverName;
  final String title;
  final String? reminderType;
  final String scheduleTime;
  final String? repeatPattern;
  final bool active;

  Reminder({
    required this.id,
    required this.elderlyId,
    this.elderlyName,
    this.accountId,
    this.caregiverId,
    this.caregiverName,
    required this.title,
    this.reminderType,
    required this.scheduleTime,
    this.repeatPattern,
    required this.active,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] ?? 0,
        elderlyId: json['elderlyId'] ?? 0,
        elderlyName: json['elderlyName'],
        accountId: json['accountId'],
        caregiverId: json['caregiverId'],
        caregiverName: json['caregiverName'],
        title: json['title'] ?? '',
        reminderType: json['reminderType'],
        scheduleTime: json['scheduleTime'] ?? '',
        repeatPattern: json['repeatPattern'],
        active: json['active'] ?? false,
      );

  DateTime? get scheduleDateTime {
    try { return DateTime.parse(scheduleTime).toLocal(); }
    catch (_) { return null; }
  }
}

class ReminderRequest {
  final int elderlyId;
  final int? caregiverId;
  final String title;
  final String? reminderType;
  final String scheduleTime;
  final String? repeatPattern;
  final bool active;

  ReminderRequest({
    required this.elderlyId,
    this.caregiverId,
    required this.title,
    this.reminderType,
    required this.scheduleTime,
    this.repeatPattern,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'elderlyId': elderlyId,
        if (caregiverId != null) 'caregiverId': caregiverId,
        'title': title,
        if (reminderType != null) 'reminderType': reminderType,
        'scheduleTime': scheduleTime,
        if (repeatPattern != null) 'repeatPattern': repeatPattern,
        'active': active,
      };
}

// ─── REMINDER LOG ─────────────────────────────────────────────────────────────
// Response từ GET /api/reminder-logs/elderly/{elderlyId}
class ReminderLog {
  final int id;
  final int reminderId;
  final String reminderTitle;
  final int? robotId;
  final String? robotName;
  final int elderlyId;
  final String? elderlyName;
  final String triggeredTime;
  final bool confirmed;
  final String? confirmedTime;

  ReminderLog({
    required this.id,
    required this.reminderId,
    required this.reminderTitle,
    this.robotId,
    this.robotName,
    required this.elderlyId,
    this.elderlyName,
    required this.triggeredTime,
    required this.confirmed,
    this.confirmedTime,
  });

  factory ReminderLog.fromJson(Map<String, dynamic> json) => ReminderLog(
        id: json['id'] ?? 0,
        reminderId: json['reminderId'] ?? 0,
        reminderTitle: json['reminderTitle'] ?? '',
        robotId: json['robotId'],
        robotName: json['robotName'],
        elderlyId: json['elderlyId'] ?? 0,
        elderlyName: json['elderlyName'],
        triggeredTime: json['triggeredTime'] ?? '',
        confirmed: json['confirmed'] ?? false,
        confirmedTime: json['confirmedTime'],
      );

  DateTime? get triggeredDateTime {
    try { return DateTime.parse(triggeredTime).toLocal(); }
    catch (_) { return null; }
  }

  DateTime? get confirmedDateTime {
    if (confirmedTime == null) return null;
    try { return DateTime.parse(confirmedTime!).toLocal(); }
    catch (_) { return null; }
  }
}

// ─── EXERCISE ─────────────────────────────────────────────────────────────────
class Exercise {
  final int id;
  final String name;
  final String? code;
  final String? type;
  final String? description;
  final int? duration;

  Exercise({
    required this.id,
    required this.name,
    this.code,
    this.type,
    this.description,
    this.duration,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        code: json['code'],
        type: json['type'],
        description: json['description'],
        duration: json['duration'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (code != null) 'code': code,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (duration != null) 'duration': duration,
      };

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (code != null) 'code': code,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (duration != null) 'duration': duration,
      };
}

// ─── ALERT NOTIFICATION ───────────────────────────────────────────────────────
class AlertNotification {
  final int id;
  final int elderlyId;
  final String? elderlyName;
  final int? reminderLogId;
  final String? alertType;
  final String? message;
  final bool resolved;
  final String createdAt;

  AlertNotification({
    required this.id,
    required this.elderlyId,
    this.elderlyName,
    this.reminderLogId,
    this.alertType,
    this.message,
    required this.resolved,
    required this.createdAt,
  });

  factory AlertNotification.fromJson(Map<String, dynamic> json) =>
      AlertNotification(
        id: json['id'] ?? 0,
        elderlyId: json['elderlyId'] ?? 0,
        elderlyName: json['elderlyName'],
        reminderLogId: json['reminderLogId'],
        alertType: json['alertType'],
        message: json['message'],
        resolved: json['resolved'] ?? false,
        createdAt: json['createdAt'] ?? '',
      );

  DateTime? get createdDateTime {
    try { return DateTime.parse(createdAt).toLocal(); }
    catch (_) { return null; }
  }

  bool get isUnresolved => !resolved;
}

// ─── ACTION LIBRARY (Exercise) ────────────────────────────────────────────────
class ActionLibrary {
  final int id;
  final String name;
  final String? code;
  final String? type;
  final String? description;
  final int? duration;

  ActionLibrary({
    required this.id,
    required this.name,
    this.code,
    this.type,
    this.description,
    this.duration,
  });

  factory ActionLibrary.fromJson(Map<String, dynamic> json) => ActionLibrary(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        code: json['code'],
        type: json['type'],
        description: json['description'],
        duration: json['duration'],
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (code != null) 'code': code,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (duration != null) 'duration': duration,
      };
}

// ─── ROBOT ACTION ─────────────────────────────────────────────────────────────
class RobotAction {
  final int id;
  final String action; // code của động tác
  final bool executed;

  RobotAction({required this.id, required this.action, required this.executed});

  factory RobotAction.fromJson(Map<String, dynamic> json) => RobotAction(
        id: json['id'] ?? 0,
        action: json['action'] ?? '',
        executed: json['executed'] ?? false,
      );
}
