// lib/utils/constants.dart

class AppConstants {
  static const String baseUrl = 'https://sep490-be-3.onrender.com';
  static const String userKey = 'user_data';
  static const List<String> allowedRoles = ['FAMILYMEMBER'];
}

class ApiEndpoints {
  // Auth
  static const String login = '/api/login';
  static const String logout = '/api/logout';

  // Elderly Profile
  static String createElderlyForAccount(int accountId) =>
      '/api/elderly-profile/$accountId';
  static String elderlyByAccount(int accountId) =>
      '/api/elderly-profile/account/$accountId';
  static String elderlyProfileById(int id) => '/api/elderly-profile/$id';

  // Reminder
  static const String reminders = '/api/reminders';
  static String reminderById(int id) => '/api/reminders/$id';
  static String remindersByElderly(int elderlyId) =>
      '/api/reminders/elderly/$elderlyId';

  // Reminder Log
  static const String reminderLogs = '/api/reminder-logs';
  static String reminderLogsByElderly(int elderlyId) =>
      '/api/reminder-logs/elderly/$elderlyId';
  static String confirmReminderLog(int id) =>
      '/api/reminder-logs/$id/confirm';

  // Exercise
  static const String exercises = '/api/exercises';
  static String exerciseById(int id) => '/api/exercises/$id';
  static String sendExerciseToRobot(int id) =>
      '/api/exercises/$id/send-to-robot';


  // Alert Notification
  static const String alerts = '/api/alerts';
  static String alertsByElderly(int elderlyId) => '/api/alerts/elderly/$elderlyId';
  static String alertsByReminder(int reminderId) => '/api/alerts/reminder/$reminderId';
  static String alertById(int id) => '/api/alerts/$id';

  // Action Library (Exercise)
  static const String actionLibrary = '/api/action-library';
  static String actionLibraryById(int id) => '/api/action-library/$id';

  // Robot Action
  static const String robotAction = '/api/robot-action';
  static String robotActionDone(int id) => '/api/robot-action/$id/done';
  static const String robotActionLatest = '/api/robot-action/latest';
}