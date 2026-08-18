import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/remarks_template_entity.dart';

part 'remarks_template_dto.freezed.dart';
part 'remarks_template_dto.g.dart';

@freezed
class RemarksTemplateDto with _$RemarksTemplateDto {
  const factory RemarksTemplateDto({
    required List<String> templates,
  }) = _RemarksTemplateDto;

  const RemarksTemplateDto._();

  factory RemarksTemplateDto.fromJson(Map<String, dynamic> json) =>
      _$RemarksTemplateDtoFromJson(json);

  RemarksTemplateEntity toEntity() {
    return RemarksTemplateEntity(
      templates: templates,
    );
  }
}
