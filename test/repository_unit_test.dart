import 'package:flutter_test/flutter_test.dart';
import 'package:my_mail/domain/entities/category_entity.dart';
import 'package:my_mail/domain/entities/credential_entity.dart';

void main() {
  group('Entity & Data Model Contract Unit Tests', () {
    final now = DateTime.now().toUtc();

    test('CategoryEntity serialization & copyWith', () {
      final category = CategoryEntity(
        id: 'cat_custom',
        name: 'Finance',
        isLocked: true,
        isDefault: false,
        sortOrder: 3,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      final map = category.toMap();
      expect(map['id'], equals('cat_custom'));
      expect(map['is_locked'], equals(1));
      expect(map['is_deleted'], equals(0));

      final restored = CategoryEntity.fromMap(map);
      expect(restored.name, equals('Finance'));
      expect(restored.isLocked, isTrue);

      final modified = category.copyWith(name: 'Banking');
      expect(modified.name, equals('Banking'));
      expect(modified.id, equals('cat_custom'));
    });

    test('CredentialEntity UUID, timestamps and soft delete flags', () {
      final credential = CredentialEntity(
        id: 'uuid-1234-5678',
        categoryId: 'cat_work',
        email: 'dev@company.com',
        password: 'Password99#',
        label: 'Production Admin',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      final json = credential.toJson();
      expect(json['id'], equals('uuid-1234-5678'));
      expect(json['email'], equals('dev@company.com'));
      expect(json['label'], equals('Production Admin'));
      expect(json['isDeleted'], isFalse);

      final fromJson = CredentialEntity.fromJson(json);
      expect(fromJson.email, equals('dev@company.com'));
      expect(fromJson.label, equals('Production Admin'));

      final softDeleted = credential.copyWith(isDeleted: true);
      expect(softDeleted.isDeleted, isTrue);
    });
  });
}
