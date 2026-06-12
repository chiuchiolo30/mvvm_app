import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dtos/pokemon_page_dto.dart';

abstract class PokemonListRemoteDataSource {
  Future<PokemonPageDto> getPokemonPage({
    required int limit,
    required int offset,
  });
}

class HttpPokemonListRemoteDataSource implements PokemonListRemoteDataSource {
  const HttpPokemonListRemoteDataSource(this._client);

  static const _baseUrl = 'pokeapi.co';
  static const _pokemonPath = '/api/v2/pokemon';

  final http.Client _client;

  @override
  Future<PokemonPageDto> getPokemonPage({
    required int limit,
    required int offset,
  }) async {
    final uri = Uri.https(_baseUrl, _pokemonPath, {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PokemonListRemoteException(
        'Invalid status code: ${response.statusCode}',
      );
    }

    return PokemonPageDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class PokemonListRemoteException implements Exception {
  const PokemonListRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}
