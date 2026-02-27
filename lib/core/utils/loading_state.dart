/// Loading state management
/// إدارة حالات التحميل
library;

enum LoadingState { initial, loading, loaded, error }

extension LoadingStateExtension on LoadingState {
  bool get isInitial => this == LoadingState.initial;
  bool get isLoading => this == LoadingState.loading;
  bool get isLoaded => this == LoadingState.loaded;
  bool get isError => this == LoadingState.error;
}


