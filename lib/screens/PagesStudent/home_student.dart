import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/app_user.dart';
import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';

/// Pantalla raíz del estudiante: inicio, asistencia y perfil (compartido).
class HomeStudentScreen extends StatefulWidget {
  const HomeStudentScreen({super.key});

  @override
  State<HomeStudentScreen> createState() => _HomeStudentScreenState();
}

class _HomeStudentScreenState extends State<HomeStudentScreen> {
  // "Asistencia" y "Perfil" se navegan como pantallas aparte (con su propio botón de
  // volver), así que el índice del nav siempre se queda en "Inicio".
  static const _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(child: _HomeTab()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.surfaceContainerHigh,
        onDestinationSelected: (i) {
          if (i == 1) {
            Navigator.pushNamed(context, AppRoutes.attendanceReport);
          } else if (i == 2) {
            Navigator.pushNamed(context, AppRoutes.profile);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Asistencia',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Course>? _courses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCoursesForUser(AppUser? user) async {
    if (user?.studentCode == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final courses = await CourseRepository.instance.fetchCoursesForStudentCode(user!.studentCode!);
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _isLoading = false;
    });
  }

  Future<void> _loadCourses() async {
    final user = await AuthService.instance.getCurrentAppUser();
    await _loadCoursesForUser(user);
  }

  void _openRegisterAttendance(Course course) {
    Navigator.pushNamed(context, AppRoutes.registerAttendance, arguments: course);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.watchCurrentAppUser(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final courses = _courses ?? const <Course>[];
        final liveCourse = courses.where((c) => c.hasLiveSession).toList();

        return RefreshIndicator(
          onRefresh: () => _loadCoursesForUser(user),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildGreeting(context, user, courses.length),
              const SizedBox(height: 16),
              liveCourse.isEmpty ? _buildNoActiveClassCard() : _buildActiveClassCard(liveCourse.first),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mis Cursos Inscritos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '${courses.length} Asignaturas',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (courses.isEmpty)
                _buildEmptyCoursesState(user)
              else
                for (final course in courses) ...[
                  _buildCourseCard(course),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreeting(BuildContext context, AppUser? user, int courseCount) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Hola, ${user?.fullName ?? ''}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👋', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                courseCount == 0 ? 'Aún no tienes asignaturas inscritas' : '$courseCount asignaturas inscritas',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.surfaceContainerHigh,
          backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          child: user?.photoUrl == null
              ? Text(
                  user?.initials ?? '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildActiveClassCard(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33003EA8), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.tertiaryFixed),
                    SizedBox(width: 6),
                    Text('CLASE ACTIVA',
                        style: TextStyle(color: AppColors.onPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.primaryFixed),
                  const SizedBox(width: 4),
                  Text('Finaliza en ${course.liveSessionMinutesLeft} min',
                      style: const TextStyle(color: AppColors.primaryFixed, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(course.name, style: const TextStyle(color: AppColors.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.meeting_room, size: 14, color: AppColors.primaryFixed),
              const SizedBox(width: 4),
              Text(course.room, style: const TextStyle(color: AppColors.primaryFixed, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerLowest,
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openRegisterAttendance(course),
              icon: const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.secondary),
              label: const Text('Registrar Asistencia Ahora', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveClassCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
            child: const Icon(Icons.bedtime_outlined, color: AppColors.outline, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No tienes clases activas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  'Cuando tu docente abra una sesión de asistencia, aparecerá aquí.',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCoursesState(AppUser? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, color: AppColors.outline, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Aún no estás matriculado en ningún curso',
            style: TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            user?.studentCode == null
                ? 'No encontramos un código universitario en tu perfil.'
                : 'Pide a tu docente que te agregue con tu código: ${user!.studentCode}',
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'Grupo ${course.group}${course.teacherName != null ? ' • Prof. ${course.teacherName}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                child: const Text(
                  'Sin datos',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.outline),
              const SizedBox(width: 6),
              Text(
                '${course.daysRangeLabel} ${course.scheduleRange}',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
