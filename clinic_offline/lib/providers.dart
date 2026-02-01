import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db/app_db.dart';
import 'data/repositories/appointments_repository.dart';
import 'data/repositories/analytics_repository.dart';
import 'data/repositories/patients_repository.dart';
import 'data/repositories/photos_repository.dart';
import 'data/repositories/procedures_repository.dart';
import 'data/repositories/visit_procedures_repository.dart';
import 'data/repositories/visits_repository.dart';
import 'services/app_lock_service.dart';
import 'services/app_paths.dart';
import 'services/backup_service.dart';
import 'services/image_storage_service.dart';

final appPathsProvider = Provider<AppPaths>((ref) => const AppPaths());

final databaseProvider = Provider<AppDatabase>((ref) {
  final paths = ref.watch(appPathsProvider);
  final db = AppDatabase(paths);
  ref.onDispose(db.close);
  return db;
});

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return PatientsRepository(ref.watch(databaseProvider));
});

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) {
  return VisitsRepository(ref.watch(databaseProvider));
});

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(databaseProvider));
});

final photosRepositoryProvider = Provider<PhotosRepository>((ref) {
  return PhotosRepository(ref.watch(databaseProvider));
});

final proceduresRepositoryProvider = Provider<ProceduresRepository>((ref) {
  return ProceduresRepository(ref.watch(databaseProvider));
});

final visitProceduresRepositoryProvider =
    Provider<VisitProceduresRepository>((ref) {
  return VisitProceduresRepository(ref.watch(databaseProvider));
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(databaseProvider));
});

final imageStorageProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService(ref.watch(appPathsProvider));
});

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    paths: ref.watch(appPathsProvider),
    db: ref.watch(databaseProvider),
  );
});
