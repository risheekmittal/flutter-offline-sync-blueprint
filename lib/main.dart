```dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// -----------------------------------------------------------------------------
// DOMAIN LAYER (Interfaces & Entities)
// -----------------------------------------------------------------------------

/// State representing the synchronization status of the application.
enum SyncStatus { initial, syncing, success, failure }

abstract class SyncRepository {
  Future<void> synchronizeData();
  Stream<SyncStatus> get syncStatus;
}

// -----------------------------------------------------------------------------
// DATA LAYER (Implementation)
// -----------------------------------------------------------------------------

class SyncRepositoryImpl implements SyncRepository {
  final _statusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatus => _statusController.stream;

  @override
  Future<void> synchronizeData() async {
    _statusController.add(SyncStatus.syncing);
    try {
      // Simulate network/database latency
      await Future.delayed(const Duration(seconds: 2));
      _statusController.add(SyncStatus.success);
    } catch (e) {
      log('Sync failed: $e');
      _statusController.add(SyncStatus.failure);
    }
  }

  void dispose() => _statusController.close();
}

// -----------------------------------------------------------------------------
// PRESENTATION LAYER (BloC)
// -----------------------------------------------------------------------------

abstract class SyncEvent {}
class TriggerSyncEvent extends SyncEvent {}

class SyncState {
  final SyncStatus status;
  const SyncState({this.status = SyncStatus.initial});
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository _repository;
  StreamSubscription? _statusSubscription;

  SyncBloc(this._repository) : super(const SyncState()) {
    on<TriggerSyncEvent>((event, emit) async {
      await _repository.synchronizeData();
    });

    // Listen to repository stream to react to data-layer changes
    _statusSubscription = _repository.syncStatus.listen((status) {
      // Internal state update based on domain logic
      add(_UpdateStatusInternal(status));
    });

    on<_UpdateStatusInternal>((event, emit) {
      emit(SyncState(status: event.status));
    });
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}

class _UpdateStatusInternal extends SyncEvent {
  final SyncStatus status;
  _UpdateStatusInternal(this.status);
}

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------

void main() {
  // Capture Flutter Framework errors
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialization of services/local DBs would happen here
      final syncRepository = SyncRepositoryImpl();

      runApp(
        OfflineSyncApp(syncRepository: syncRepository),
      );
    },
    (error, stack) => log('Uncaught error: $error', stackTrace: stack),
  );
}

class OfflineSyncApp extends StatelessWidget {
  final SyncRepository syncRepository;

  const OfflineSyncApp({
    super.key,
    required this.syncRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SyncRepository>.value(value: syncRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SyncBloc(context.read<SyncRepository>()),
          ),
        ],
        child: MaterialApp(
          title: 'Offline Sync Blueprint',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: const SyncHomeScreen(),
        ),
      ),
    );
  }
}

class SyncHomeScreen extends StatelessWidget {
  const SyncHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Clean Architecture')),
      body: Center(
        child: BlocBuilder<SyncBloc, SyncState>(
          builder: (context, state) {
            switch (state.status) {
              case SyncStatus.initial:
                return const Text('Ready to Sync');
              case SyncStatus.syncing:
                return const CircularProgressIndicator();
              case SyncStatus.success:
                return const Text('Data Synchronized Successfully', style: TextStyle(color: Colors.green));
              case SyncStatus.failure:
                return const Text('Sync Failed', style: TextStyle(color: Colors.red));
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<SyncBloc>().add(TriggerSyncEvent()),
        child: const Icon(Icons.sync),
      ),
    );
  }
}
```