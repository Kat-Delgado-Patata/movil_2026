import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/app_user.dart';
import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';
import 'attendance_history_tab.dart';
import 'teacher_report_tab.dart';

class HomeTeacherScreen extends StatefulWidget {
  const HomeTeacherScreen({super.key});

  @override
  State<HomeTeacherScreen> createState() => _HomeTeacherScreenState();
}

class _HomeTeacherScreenState extends State<HomeTeacherScreen> {
  int _tabIndex = 0;

  String? get _teacherUid => AuthService.instance.currentUser?.uid;

  /// Curso de hoy que todavía no termina y empieza primero; si no hay, el primero de la lista.
  Course? _nextCourseOf(List<Course> courses) {
    final today = courses.where((c) => c.isToday && c.minutesUntilStart > -120).toList()
      ..sort((a, b) => a.minutesUntilStart.compareTo(b.minutesUntilStart));
    if (today.isNotEmpty) return today.first;
    return courses.isEmpty ? null : courses.first;
  }

  String _startsInLabel(Course course) {
    if (!course.isToday) return course.nextClassLabel;
    final minutes = course.minutesUntilStart;
    if (minutes <= 0) return 'En curso';
    if (minutes < 60) return 'En $minutes minutos';
    return 'Hoy ${Course.formatTime(course.startTime)}';
  }

  void _startAttendance(Course course) {
    Navigator.pushNamed(context, AppRoutes.startSession, arguments: course);
  }

  void _openCourseDetail(Course course) {
    if (course.id == null) return;
    Navigator.pushNamed(context, AppRoutes.courseDetail, arguments: course.id);
  }

  Future<void> _registerCourse() async {
    final created = await Navigator.pushNamed(context, AppRoutes.registerCourse);
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Curso registrado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_tabIndex) {
          0 => _buildHomeStream(),
          1 => const TeacherReportTab(),
          2 => const AttendanceHistoryTab(),
          _ => _buildPlaceholderTab(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.surfaceContainerHigh,
        onDestinationSelected: (i) {
          if (i == 3) {
            Navigator.pushNamed(context, AppRoutes.profile);
            return;
          }
          setState(() => _tabIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab() {
    return const Center(
      child: Text('Próximamente', style: TextStyle(color: AppColors.onSurfaceVariant)),
    );
  }

  Widget _buildHomeStream() {
    final uid = _teacherUid;
    if (uid == null) {
      return const Center(
        child: Text('Inicia sesión para continuar', style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }
    return StreamBuilder<List<Course>>(
      stream: CourseRepository.instance.watchTeacherCourses(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildHome(snapshot.data ?? const []);
      },
    );
  }

  Widget _buildHome(List<Course> courses) {
    final next = _nextCourseOf(courses);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildGreeting(context),
        const SizedBox(height: 20),
        if (next != null) ...[
          _buildNextSessionCard(next),
          const SizedBox(height: 16),
        ],
        _buildRegisterButton(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mis Cursos Activos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              '${courses.length} cursos',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (courses.isEmpty) _buildEmptyState(),
        for (final course in courses) ...[
          _buildCourseCard(course, isNext: next != null && course.id == next.id),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 32, color: AppColors.outline),
          SizedBox(height: 10),
          Text(
            'Aún no tienes cursos registrados',
            style: TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Usa "Registrar Nuevo Curso" para dar de alta tu primera asignatura.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.watchCurrentAppUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.fullName ?? '';
        final initials = user?.initials ?? '--';
        final faculty = user?.faculty;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $name',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (faculty != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            faculty,
                            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _buildAvatar(initials),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(String initials) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          child: Text(
            initials,
            style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.onTertiaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextSessionCard(Course course) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33003EA8), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 24,
            child: Icon(Icons.functions, size: 72, color: Color(0x1FFFFFFF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: AppColors.tertiaryFixedDim),
                        SizedBox(width: 6),
                        Text(
                          'Próxima Sesión',
                          style: TextStyle(color: AppColors.onPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _startsInLabel(course),
                    style: const TextStyle(color: AppColors.onPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                course.name,
                style: const TextStyle(color: AppColors.onPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Grupo ${course.group} • ${course.students} Alumnos',
                style: const TextStyle(color: AppColors.primaryFixed, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _whiteInfo(Icons.meeting_room_outlined, course.room),
                  _whiteInfo(Icons.schedule, course.scheduleRange),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerLowest,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _startAttendance(course),
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Iniciar Asistencia', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whiteInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.onPrimary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _registerCourse,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Registrar Nuevo Curso',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course, {required bool isNext}) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCourseDetail(course),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'Grupo ${course.group} • ${course.students} Alumnos',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  course.nextClassLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: isNext
                    ? const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppColors.tertiaryContainer),
                          SizedBox(width: 6),
                          Text('Sesión lista', style: TextStyle(fontSize: 12, color: AppColors.tertiaryContainer)),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(course.room, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLow,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isNext ? () => _startAttendance(course) : () => _openCourseDetail(course),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNext ? 'Gestionar Clase' : 'Ver Detalle',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}
