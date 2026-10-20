enum TaskType {
  easy('Easy'),
  moderate('Moderate'),
  hard('Hard');

  final String label;
  const TaskType(this.label);
}

class Task {
  final int? id;
  final String title;
  final String content;
  final DateTime date;
  final TaskType type;
  final bool isCompleted;
  final DateTime createdAt;

  const Task({
    this.id,
    required this.title,
    this.content = '',
    required this.date,
    this.type = TaskType.easy,
    this.isCompleted = false,
    required this.createdAt,
  });

  Task copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? date,
    TaskType? type,
    bool? isCompleted,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    date: date ?? this.date,
    type: type ?? this.type,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'content': content,
    'due_date': date.toIso8601String(),
    'type': type.name,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id'] as int,
    title: map['title'] as String,
    content: map['content'] as String,
    date: DateTime.parse(map['due_date'] as String),
    type: TaskType.values.byName(map['type'] as String),
    isCompleted: map['is_completed'] == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
