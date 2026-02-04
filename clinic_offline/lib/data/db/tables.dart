import 'package:drift/drift.dart';

class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get gender => text().nullable()();
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

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitCost => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductUsages extends Table {
  TextColumn get id => text()();
  TextColumn get visitId => text().references(Visits, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ManualIncomes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get incomeAt => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Procedures extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get defaultPrice => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VisitProcedures extends Table {
  TextColumn get id => text()();
  TextColumn get visitId => text().references(Visits, #id)();
  TextColumn get procedureId => text().references(Procedures, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPrice => integer()();
  IntColumn get discount => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
