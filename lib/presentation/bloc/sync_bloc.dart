```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// --- Events ---

/// Base class for all Synchronization events.
abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the user or system requests a manual synchronization.
class SyncRequested extends SyncEvent {
  const SyncRequested();
}

/// Internal event used to handle stream updates from a sync monitoring service.
class _SyncStatusUpdated extends SyncEvent {
  final SyncStatus status;
  final String? errorMessage;

  const _SyncStatusUpdated(this.status, {this.errorMessage});

  @override
  List<Object?> get props => [status, errorMessage];
}

// --- States ---

/// Enum representing the discrete phases of the synchronization process.
enum SyncStatus { initial, loading, success, failure }

/// Represents the state of the offline synchronization process.
class SyncState extends Equatable {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.initial,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, lastSyncTime];
}

// --- Domain Interface (Placeholder for Clean Arch compliance) ---

/// Contract for the Synchronization UseCase/Service.
/// This allows the Bloc to remain agnostic of the data source implementation.
abstract class SynchronizeDataUseCase {
  Future<void> call();
}

// --- Bloc Implementation ---

/// [SyncBloc] manages the orchestration of offline data synchronization.
///
/// It follows the Clean Architecture pattern by depending on an abstract UseCase
/// and emitting immutable states to the UI layer.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SynchronizeDataUseCase _synchronizeDataUseCase;

  SyncBloc({
    required SynchronizeDataUseCase synchronizeDataUseCase,
  })  : _synchronizeDataUseCase = synchronizeDataUseCase,
        super(const SyncState()) {
    on<SyncRequested>(_onSyncRequested);
    on<_SyncStatusUpdated>(_onSyncStatusUpdated);
  }

  /// Handles the explicit request to synchronize local data with the remote server.
  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    // Prevent concurrent sync executions
    if (state.status == SyncStatus.loading) return;

    emit(state.copyWith(status: SyncStatus.loading));

    try {
      // Execute the business logic defined in the domain layer
      await _synchronizeDataUseCase.call();
      
      add(_SyncStatusUpdated(
        SyncStatus.success,
        errorMessage: null,
      ));
    } catch (e) {
      add(_SyncStatusUpdated(
        SyncStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Internal handler to transition states based on sync outcomes.
  void _onSyncStatusUpdated(
    _SyncStatusUpdated event,
    Emitter<SyncState> emit,
  ) {
    emit(state.copyWith(
      status: event.status,
      errorMessage: event.errorMessage,
      lastSyncTime: event.status == SyncStatus.success ? DateTime.now() : state.lastSyncTime,
    ));
  }
}
```