import 'package:equatable/equatable.dart';

class AcademicYearEntity extends Equatable {
  final String id;
  final String name;
  final String code;
  final String status;

  const AcademicYearEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
  });

  @override
  List<Object?> get props => [id, name, code, status];
}
