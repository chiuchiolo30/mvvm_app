import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/pokemon_page.dart';
import '../../domain/failures/pokemon_list_failure.dart';
import '../../domain/repositories/pokemon_list_repository.dart';
import '../datasources/pokemon_list_remote_datasource.dart';
import '../mappers/pokemon_page_mapper.dart';

class PokemonListRepositoryImpl implements PokemonListRepository {
  const PokemonListRepositoryImpl({
    required PokemonListRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final PokemonListRemoteDataSource _remoteDataSource;

  @override
  Future<Either<PokemonListFailure, PokemonPage>> getPokemonPage({
    required int limit,
    required int offset,
  }) async {
    try {
      final dto = await _remoteDataSource.getPokemonPage(
        limit: limit,
        offset: offset,
      );

      return Right(dto.toDomain(currentOffset: offset, limit: limit));
    } on SocketException {
      return const Left(PokemonListNetworkFailure());
    } on http.ClientException {
      return const Left(PokemonListNetworkFailure());
    } on PokemonListRemoteException {
      return const Left(PokemonListNetworkFailure());
    } catch (error, stackTrace) {
      return Left(
        PokemonListUnexpectedFailure(error: error, stackTrace: stackTrace),
      );
    }
  }
}
