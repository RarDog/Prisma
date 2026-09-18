import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';

class ProviderCheckService {
  ProviderCheckService(this._repository, this._factory, this._manager);

  final ProviderRepository _repository;
  final ProviderFactory _factory;
  final ProviderManager _manager;

  Future<Result<ProviderHealth>> checkOne(String providerId) async {
    final configResult = await _repository.getProvider(providerId);
    if (configResult is Error<ContentProviderConfig?>) {
      return Error(configResult.failure);
    }
    final config = (configResult as Success<ContentProviderConfig?>).data;
    if (config == null) {
      return const Error(
        Failure(code: 'not_found', message: 'Provider not found'),
      );
    }
    final health = await _factory.create(config).checkHealth();
    await _repository.saveHealth(health);
    return Success(health);
  }

  Future<Result<List<ProviderHealth>>> checkAll() {
    return _manager.checkAll(concurrency: 3);
  }
}
