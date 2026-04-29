import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/features/auth/data/auth_repository_impl.dart';
import 'package:tiendaw/features/auth/data/auth_sources.dart';
import 'package:tiendaw/features/auth/domain/load_current_user_use_case.dart';
import 'package:tiendaw/features/auth/domain/sign_in_use_case.dart';
import 'package:tiendaw/features/auth/domain/sign_out_use_case.dart';
import 'package:tiendaw/features/catalog/data/catalog_repository_impl.dart';
import 'package:tiendaw/features/catalog/data/catalog_sources.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/purchases/data/purchase_repository_impl.dart';
import 'package:tiendaw/features/purchases/data/purchase_sources.dart';
import 'package:tiendaw/features/purchases/domain/register_purchase_use_case.dart';
import 'package:tiendaw/features/sales/data/sales_repository_impl.dart';
import 'package:tiendaw/features/sales/data/sales_sources.dart';
import 'package:tiendaw/features/sales/domain/create_sale_use_case.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.read(supabaseClientProvider));
});

// Invitation link deshabilitado temporalmente.
// final authInviteLinkSourceProvider = Provider<AuthInviteLinkSource>((ref) {
//   return AuthInviteLinkSource();
// });

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

final loadCurrentUserUseCaseProvider = Provider<LoadCurrentUserUseCase>((ref) {
  return LoadCurrentUserUseCase(ref.read(authRepositoryProvider));
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.read(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.read(authRepositoryProvider));
});

// Invitation link deshabilitado temporalmente.
// final completeInvitedUserPasswordUseCaseProvider =
//     Provider<CompleteInvitedUserPasswordUseCase>((ref) {
//       return CompleteInvitedUserPasswordUseCase(
//         ref.read(authRepositoryProvider),
//       );
//     });

final catalogLocalDataSourceProvider = Provider<CatalogLocalDataSource>((ref) {
  return CatalogLocalDataSource();
});

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>((
  ref,
) {
  return CatalogRemoteDataSource(ref.read(supabaseClientProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepositoryImpl>((ref) {
  return CatalogRepositoryImpl(
    local: ref.read(catalogLocalDataSourceProvider),
    remote: ref.read(catalogRemoteDataSourceProvider),
  );
});

final loadCatalogOverviewUseCaseProvider = Provider<LoadCatalogOverviewUseCase>(
  (ref) {
    return LoadCatalogOverviewUseCase(ref.read(catalogRepositoryProvider));
  },
);

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>((ref) {
  return SalesLocalDataSource();
});

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>((ref) {
  return SalesRemoteDataSource(ref.read(supabaseClientProvider));
});

final salesRepositoryProvider = Provider<SalesRepositoryImpl>((ref) {
  return SalesRepositoryImpl(
    local: ref.read(salesLocalDataSourceProvider),
    remote: ref.read(salesRemoteDataSourceProvider),
  );
});

final createSaleUseCaseProvider = Provider<CreateSaleUseCase>((ref) {
  return CreateSaleUseCase(ref.read(salesRepositoryProvider));
});

final purchaseLocalDataSourceProvider = Provider<PurchaseLocalDataSource>((
  ref,
) {
  return PurchaseLocalDataSource();
});

final purchaseRemoteDataSourceProvider = Provider<PurchaseRemoteDataSource>((
  ref,
) {
  return PurchaseRemoteDataSource(ref.read(supabaseClientProvider));
});

final purchaseRepositoryProvider = Provider<PurchaseRepositoryImpl>((ref) {
  return PurchaseRepositoryImpl(
    local: ref.read(purchaseLocalDataSourceProvider),
    remote: ref.read(purchaseRemoteDataSourceProvider),
  );
});

final registerPurchaseUseCaseProvider = Provider<RegisterPurchaseUseCase>((
  ref,
) {
  return RegisterPurchaseUseCase(ref.read(purchaseRepositoryProvider));
});
