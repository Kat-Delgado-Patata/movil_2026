import 'package:flutter/material.dart';

import '../screens/auth/user_management/create_an_account.dart';
import '../screens/auth/authentication/forgot_password.dart';
import '../screens/auth/authentication/login_screen.dart';
import '../screens/auth/authentication/new_password.dart';
import '../screens/auth/user_management/verify_account.dart';
import '../screens/PagesStudent/attendance_report.dart';
import '../screens/PagesStudent/attendance_status.dart';
import '../screens/PagesStudent/home_student.dart';
import '../screens/PagesStudent/register_attendance.dart';
import '../screens/PagesTeacher/course_detail.dart';
import '../screens/PagesTeacher/course_roster.dart';
import '../screens/PagesTeacher/home_teacher.dart';
import '../screens/PagesTeacher/live_session.dart';
import '../screens/PagesTeacher/register_course.dart';
import '../screens/PagesTeacher/session_detail.dart';
import '../screens/PagesTeacher/start_session.dart';
import '../screens/shared/profile_screen.dart';

/// Rutas con nombre de la aplicación.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const createAccount = '/create-account';
  static const verifyAccount = '/verify-account';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const profile = '/profile';
  static const homeStudent = '/student';
  static const registerAttendance = '/student/register-attendance';
  static const attendanceStatus = '/student/attendance-status';
  static const attendanceReport = '/student/attendance-report';

  static const homeTeacher = '/teacher';
  static const startSession = '/teacher/start-session';
  static const liveSession = '/teacher/live-session';
  static const registerCourse = '/teacher/register-course';
  static const courseDetail = '/teacher/course-detail';
  static const courseRoster = '/teacher/course-roster';
  static const sessionDetail = '/teacher/session-detail';

  static const initialRoute = login;

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        createAccount: (_) => const CreateAccountScreen(),
        verifyAccount: (_) => const VerifyAccountScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        newPassword: (_) => const NewPasswordScreen(),
        profile: (_) => const ProfileScreen(),
        homeStudent: (_) => const HomeStudentScreen(),
        registerAttendance: (_) => const RegisterAttendanceScreen(),
        attendanceStatus: (_) => const AttendanceStatusScreen(),
        attendanceReport: (_) => const AttendanceReportScreen(),
        homeTeacher: (_) => const HomeTeacherScreen(),
        startSession: (_) => const StartSessionScreen(),
        liveSession: (_) => const LiveSessionScreen(),
        registerCourse: (_) => const RegisterCourseScreen(),
        courseDetail: (_) => const CourseDetailScreen(),
        courseRoster: (_) => const CourseRosterScreen(),
        sessionDetail: (_) => const SessionDetailScreen(),
      };
}
