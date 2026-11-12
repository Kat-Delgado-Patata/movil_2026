# AsistApp — Sistema de Gestión de Asistencia Universitaria

**Autora:** Katherin Vanessa Delgado Cortez

Aplicación móvil (Flutter + Firebase) para el control de asistencia universitaria con dos roles: **Docente** y **Estudiante**. El docente abre sesiones de asistencia con un código de 6 caracteres y verificación por geolocalización (el estudiante debe estar a menos de 50 m del aula); el estudiante marca presente ingresando ese código. Todo el ciclo —curso, matrícula, sesión en vivo, historial y reportes— corre sobre Firebase (Authentication + Firestore) en tiempo real.

---

## Índice

1. [Manual de usuario](#1-manual-de-usuario)
2. [Arquitectura y tecnología](#2-arquitectura-y-tecnología)
3. [Modelo de datos (Firestore)](#3-modelo-de-datos-firestore)
4. [Puesta en marcha del proyecto](#4-puesta-en-marcha-del-proyecto)
5. [Funcionalidades pendientes](#5-funcionalidades-pendientes)

---

## 1. Manual de usuario

### 1.1 Cuenta y acceso (compartido por ambos roles)

- **Crear cuenta**: correo institucional (debe terminar en `@udla.edu.co`), contraseña, y se elige el rol (**Estudiante** o **Docente**). Si el rol es Estudiante, se pide además un **código universitario** — es la clave que luego conecta la cuenta con los cursos en los que el docente lo matricule.
- **Verificar cuenta**: tras registrarse, Firebase envía un enlace de verificación al correo. Este paso es informativo; no es obligatorio para poder usar la app.
- **Iniciar sesión**: con correo y contraseña. La app enruta automáticamente a Home Docente o Home Estudiante según el rol guardado en el perfil (no según lo que se elija visualmente en la pantalla).
- **Recuperar contraseña**: envía un enlace de restablecimiento al correo.
- **Perfil** (ambos roles): datos del usuario, cambio de contraseña, cerrar sesión.

### 1.2 Flujo del Docente

| Pantalla | Qué permite hacer |
|---|---|
| **Home Docente** | Ver la próxima clase del día y la lista de cursos activos; acceso rápido para iniciar asistencia. |
| **Registrar Nuevo Curso** | Crear un curso: nombre, código/NRC, grupo, aula, periodo, días y horario. |
| **Detalle del Curso** | Métricas del curso (matriculados, sesiones, % asistencia), finalizar el semestre (modo solo lectura), eliminar el curso (solo permitido tras 12 meses finalizado), y botón para iniciar una nueva sesión de asistencia. |
| **Roster (Lista de Estudiantes)** | Agregar/editar/dar de baja estudiantes a mano, buscar, y **importar/exportar el roster en Excel (.xlsx)** — ver sección 1.4. |
| **Iniciar Sesión de Asistencia** | Elegir la duración del código (10/15/20 min o sin límite) y abrirla. En este momento la app toma la **ubicación GPS del docente**, que será el punto de referencia para validar a los estudiantes. |
| **Sesión en Vivo** | Muestra el código de 6 caracteres, el conteo de presentes en tiempo real, y permite **"Pasar Lista Manualmente"** (marcar a cada estudiante del roster como Presente / Justificada / Ausente a mano — útil si alguien no tiene celular, no tiene GPS, o para justificar una falta). También se puede regenerar el código o finalizar la sesión. |
| **Historial** | Todas las sesiones ya cerradas, filtrables por curso. Al tocar una sesión se abre su **detalle editable**: se puede corregir la asistencia de un estudiante **aunque la clase ya haya terminado** (por ejemplo, justificar una falta reportada después). |
| **Reportes** | Vista **General** (cumplimiento global, distribución presentes/ausentes/justificados, gráfico de las últimas 4 sesiones, lista de alumnos en riesgo bajo 75%) y vista **Por Clase** (detalle sesión por sesión con el estado de cada estudiante). |

### 1.3 Flujo del Estudiante

| Pantalla | Qué permite hacer |
|---|---|
| **Home Estudiante** | Si alguno de sus cursos tiene una sesión de asistencia abierta en ese momento, aparece un banner "Clase Activa" con botón para registrar asistencia. Debajo, la lista de cursos en los que está matriculado. |
| **Registrar Asistencia** | Se digita el código de 6 caracteres proyectado por el docente. La app valida: que el código sea correcto, que no haya expirado, que no se haya marcado ya, **y que el estudiante esté a menos de 50 m** de donde el docente abrió la sesión (usando el GPS del celular). |
| **Estado de Asistencia** | Comprobante del último registro (materia, hora, distancia validada, ID de validación) + una guía de errores comunes (código expirado, código incorrecto, ya registrado, ubicación desactivada/fuera de rango). |
| **Mi Reporte** | Cumplimiento general (%), desglose presentes/ausencias/justificadas, filtro por materia y por periodo académico, y el detalle de cada sesión. |

### 1.4 Importar/Exportar estudiantes desde Excel

Desde **Roster → Importar**: se elige un archivo `.xlsx` con dos columnas — **columna A: nombre completo, columna B: código universitario** (la primera fila puede ser un encabezado, se detecta y se omite sola). La app muestra cuántos estudiantes se van a agregar/actualizar antes de confirmar. Re-importar el mismo archivo no duplica: el código universitario es el identificador único de cada estudiante dentro del curso.

Desde **Roster → Exportar** se genera un `.xlsx` con el roster actual y se abre el panel nativo para compartirlo o guardarlo.

---

## 2. Arquitectura y tecnología

### 2.1 Arquitectura: MVC

El proyecto sigue el patrón **Modelo-Vista-Controlador**:

| Capa | Dónde vive | Responsabilidad |
|---|---|---|
| **Modelo** | `lib/models/` | Clases de datos puras (`Course`, `AppUser`, `AttendanceSession`...), sin lógica de UI ni de red. |
| **Vista** | `lib/screens/`, `lib/widgets/` | Solo dibuja lo que recibe y reporta las acciones del usuario (tap, texto escrito). No habla con Firebase directamente. |
| **Controlador** | `lib/services/` | Recibe la acción desde la Vista, aplica la lógica de negocio y consulta/actualiza el Modelo en Firestore (`CourseRepository`, `AuthService`, `LiveSessionRepository`, etc.). Devuelve el resultado a la Vista mediante `Stream`/`Future`. |

### 2.2 Stack

- **Flutter / Dart** — UI y lógica de la app (un solo código para Android/iOS).
- **Firebase Authentication** — cuentas de usuario (correo/contraseña), verificación y recuperación por enlace.
- **Cloud Firestore** — base de datos en tiempo real para cursos, matrículas, sesiones de asistencia, historial y reportes.
- **geolocator** — ubicación del dispositivo, usada para abrir una sesión (ubicación del docente) y para validar el radio de 50 m al marcar presente.
- **file_picker + excel + path_provider + share_plus** — importar/exportar el roster en formato `.xlsx`.
- **google_fonts** — tipografía Inter.
- Tema Material 3 con una paleta de colores propia (`lib/theme`).

### 2.3 Estructura de carpetas (`lib/`)

```
lib/
├── Firebase/            → configuración generada por FlutterFire (firebase_options.dart)
├── Routes/              → rutas con nombre de toda la app (route.dart)
├── models/              → clases de datos (AppUser, Course, CourseStudent, AttendanceSession,
│                          LiveAttendee, AttendanceCheckIn, StudentAttendanceRecord, etc.)
├── services/            → toda la lógica de acceso a Firebase, un repositorio por responsabilidad:
│   ├── auth_service.dart                    → login/registro/perfil
│   ├── course_repository.dart               → cursos
│   ├── course_student_repository.dart       → roster de un curso
│   ├── live_session_repository.dart         → ciclo de una sesión de asistencia en vivo
│   ├── attendance_session_repository.dart   → historial de sesiones cerradas
│   ├── student_attendance_repository.dart   → cruce de datos para el reporte del estudiante
│   ├── course_attendance_report_repository.dart → cruce de datos para el reporte del docente
│   ├── location_service.dart                → geolocalización
│   └── roster_excel_service.dart            → import/export de Excel
├── screens/
│   ├── auth/            → login, crear cuenta, verificar cuenta, recuperar/cambiar contraseña
│   ├── shared/          → perfil (compartida por ambos roles)
│   ├── PagesTeacher/     → todas las pantallas del docente
│   └── PagesStudent/     → todas las pantallas del estudiante
├── widgets/             → componentes reutilizables (medidor de contraseña, tarjeta de código,
│                          lista de "pasar lista")
├── theme/               → colores y ThemeData de la app
└── utils/                → validadores de formularios
```

Cada pantalla habla con Firebase **solo a través de su repositorio** en `services/` — los widgets nunca llaman a Firestore directamente, lo que mantiene la lógica de negocio centralizada y fácil de probar o cambiar.

### 2.4 Ciclo de una sesión de asistencia (resumen técnico)

1. El docente abre sesión → `LiveSessionRepository.startSession()` toma su ubicación GPS, genera un código de 6 caracteres y crea un documento en `liveSessions/`, además de reflejar el código/ubicación en el propio documento del curso (`courses/{id}.liveSessionCode`, etc.) para que el Home del estudiante detecte "clase activa" sin necesitar una consulta extra.
2. El estudiante ingresa el código → `checkIn()` valida código, vigencia y distancia (`Geolocator.distanceBetween`, máximo 50 m) antes de escribir su registro en `liveSessions/{id}/attendees/{códigoEstudiante}`.
3. El docente puede corregir manualmente cualquier estado (`setManualStatus`/`clearStatus`), tanto mientras la sesión está abierta como después de cerrada.
4. Al finalizar → `closeSession()` cuenta presentes/justificados, archiva el resumen en `attendanceSessions/` y limpia los campos de sesión activa del curso.
5. Historial, Reportes (docente) y Mi Reporte (estudiante) leen de `attendanceSessions` y cruzan con `liveSessions/*/attendees` para saber, estudiante por estudiante, si asistió.

---

## 3. Modelo de datos (Firestore)

```
users/{uid}
  firstName, lastName, email, role (student|teacher), faculty?, photoUrl?, studentCode?

courses/{courseId}
  teacherUid, teacherName, name, code, group, room, period, days, startMinutes, endMinutes,
  students, status (active|finished), sessionsCount, finishedAt?,
  liveSessionId?, liveSessionCode?, liveSessionExpiresAt?, liveSessionLat?, liveSessionLng?
  └── students/{códigoUniversitario}        → roster: fullName, code, status (active|removed)

liveSessions/{sessionId}
  courseId, code, startedAt, expiresAt, closedAt, lat, lng
  └── attendees/{códigoUniversitario}        → studentName, status (present|excused),
                                                markedManually, checkedInAt, validationId,
                                                distanceMeters?

attendanceSessions/{id}                       → resumen archivado de una sesión cerrada
  teacherUid, courseId, date, presentCount, excusedCount, totalEnrolled, liveSessionId
```

El **código universitario** del estudiante es, a propósito, el id del documento en `courses/{id}/students` y en `liveSessions/{id}/attendees` — así Firestore evita duplicados automáticamente (al matricular dos veces o al importar el mismo Excel dos veces) sin necesitar lógica adicional.

---

## 4. Puesta en marcha del proyecto

### 4.1 Requisitos

- Flutter SDK instalado y `flutter doctor` sin errores bloqueantes.
- Un emulador Android (o dispositivo físico con depuración USB activada) — el proyecto **no soporta** Windows/Web/Linux/macOS como destino porque la configuración de Firebase solo está generada para Android e iOS.

### 4.2 Configuración en la consola de Firebase (una sola vez)

1. **Authentication → Sign-in method** → habilitar **Correo electrónico/contraseña**.
2. **Firestore Database** (⚠️ no confundir con "Realtime Database", son productos distintos) → **Crear base de datos** → modo de prueba para desarrollo.
3. Correr la app y usar cada pantalla al menos una vez. Firestore pedirá crear un **índice compuesto** la primera vez que cada consulta se ejecute — esto es normal en un proyecto nuevo. El error en consola/logcat trae un link directo que ya lo deja configurado, solo hay que confirmarlo. Los índices ya identificados durante el desarrollo son:

   | Colección | Campos | Para qué pantalla |
   |---|---|---|
   | `courses` | `teacherUid` + `createdAt` (desc) | Home Docente |
   | `students` (collection group) | `code` + `status` | "Mis cursos" del estudiante |
   | `students` (por curso) | `status` + `fullName` | Roster, Sesión en vivo, Reportes |
   | `attendanceSessions` | `teacherUid` + `date` (desc) | Historial docente |
   | `attendanceSessions` | `courseId` + `date` (desc) | Reporte por curso |
   | `attendees` (collection group) | `studentCode` + `checkedInAt` (desc) | Estado de Asistencia del estudiante |

4. Antes de usar en producción: reemplazar el modo de prueba de Firestore por reglas de seguridad reales (el modo de prueba expira a los 30 días).

### 4.3 Comandos

```bash
flutter pub get
flutter run
```

---

## 5. Funcionalidades pendientes

Quedaron intencionalmente fuera del alcance (se muestran como "próximamente" en la UI, no son errores):

- Exportar reportes (docente y estudiante) a PDF.
- Importar/exportar roster en formato `.txt` (solo se implementó `.xlsx`).
- Historial de asistencias individual de un estudiante desde el Roster.
- Centro de Ayuda del perfil.
- Reglas de seguridad de Firestore para producción (hoy el proyecto corre en modo de prueba).
