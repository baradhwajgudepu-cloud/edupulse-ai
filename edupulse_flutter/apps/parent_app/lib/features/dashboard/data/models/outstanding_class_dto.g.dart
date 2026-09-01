// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outstanding_class_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OutstandingClassDtoImpl _$$OutstandingClassDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$OutstandingClassDtoImpl(
      className: json['class_name'] as String,
      outstandingAmount: (json['outstanding_amount'] as num).toDouble(),
    );

Map<String, dynamic> _$$OutstandingClassDtoImplToJson(
        _$OutstandingClassDtoImpl instance) =>
    <String, dynamic>{
      'class_name': instance.className,
      'outstanding_amount': instance.outstandingAmount,
    };
