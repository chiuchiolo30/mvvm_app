import 'package:equatable/equatable.dart';

sealed class PokemonListFailure extends Equatable {
  const PokemonListFailure();

  String get message;

  @override
  List<Object?> get props => [];
}

final class PokemonListNetworkFailure extends PokemonListFailure {
  const PokemonListNetworkFailure();

  @override
  String get message =>
      'No pudimos cargar los Pokemon. Revisa tu conexion e intenta nuevamente.';
}

final class PokemonListUnexpectedFailure extends PokemonListFailure {
  const PokemonListUnexpectedFailure({this.error, this.stackTrace});

  final Object? error;
  final StackTrace? stackTrace;

  @override
  String get message => 'Ocurrio un problema inesperado al cargar los Pokemon.';

  @override
  List<Object?> get props => [error, stackTrace];
}
