import 'package:equatable/equatable.dart';

class OutstandingClassEntity extends Equatable {
  final String className;
  final double outstandingAmount;

  const OutstandingClassEntity({
    required this.className,
    required this.outstandingAmount,
  });

  @override
  List<Object?> get props => [className, outstandingAmount];
}
