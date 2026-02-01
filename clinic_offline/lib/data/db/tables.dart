import 'package:drift/drift.dart';

class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Visits extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id)();
  DateTimeColumn get visitAt => dateTime()();
  TextColumn get complaint => text().nullable()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Appointments extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id)();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get status => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id)();
  TextColumn get visitId => text().nullable().references(Visits, #id)();
  TextColumn get kind => text()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get relativePath => text()();
  TextColumn get thumbRelativePath => text()();
  TextColumn get sha256 => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}