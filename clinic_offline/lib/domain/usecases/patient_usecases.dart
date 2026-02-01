import '../../data/repositories/patients_repository.dart';
import '../../data/db/app_db.dart';

class SavePatientUseCase {
  SavePatientUseCase(this._repo);

  final PatientsRepository _repo;

  Future<void> call(PatientsCompanion companion) {
    return _repo.upsert(companion);
  }
}