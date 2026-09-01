import 'package:flutter/material.dart';
import '../../domain/entities/homework.dart';
import 'homework_card.dart';

class HomeworkList extends StatelessWidget {
  final List<HomeworkEntity> homeworks;

  const HomeworkList({super.key, required this.homeworks});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: homeworks.length,
      itemBuilder: (context, index) {
        final item = homeworks[index];
        return HomeworkCard(homework: item);
      },
    );
  }
}
