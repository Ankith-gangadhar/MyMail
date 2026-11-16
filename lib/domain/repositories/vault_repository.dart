import '../entities/category_entity.dart';
import '../entities/credential_entity.dart';

abstract class VaultRepository {
  Future<List<CategoryEntity>> getCategories();
  Future<CategoryEntity?> getCategoryById(String id);
  Future<void> saveCategory(CategoryEntity category);
  Future<void> deleteCategory(String id);
  Future<void> reorderCategories(List<String> categoryIds);

  Future<List<CredentialEntity>> getCredentialsByCategory(String categoryId);
  Future<List<CredentialEntity>> getAllCredentials();
  Future<void> saveCredential(CredentialEntity credential);
  Future<void> deleteCredential(String id);

  Future<void> restoreAll({
    required List<CategoryEntity> categories,
    required List<CredentialEntity> credentials,
    required bool replace,
  });
}
