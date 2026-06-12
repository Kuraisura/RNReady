import 'package:flutter_test/flutter_test.dart';
import 'package:rn_ready/features/notes/notes_controller.dart';

void main() {
  test('Note round-trips through JSON', () {
    const note = Note(
      id: 'n1',
      title: 'Cardio',
      body: 'Preload vs afterload',
      updatedAt: 12345,
    );
    final restored = Note.fromJson(note.toJson());
    expect(restored.id, note.id);
    expect(restored.title, note.title);
    expect(restored.body, note.body);
    expect(restored.updatedAt, note.updatedAt);
  });

  test('Note.copyWith updates only given fields', () {
    const note = Note(id: 'n1', title: 'a', body: 'b', updatedAt: 1);
    final updated = note.copyWith(title: 'z', updatedAt: 2);
    expect(updated.id, 'n1');
    expect(updated.title, 'z');
    expect(updated.body, 'b');
    expect(updated.updatedAt, 2);
  });
}
