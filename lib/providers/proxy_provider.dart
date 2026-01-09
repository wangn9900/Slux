import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/proxy_node.dart';
import '../providers/api_service_provider.dart';

class ProxyState {
  final List<ProxyNode> nodes;
  final ProxyNode? selectedNode;
  final bool isLoading;
  final String? error;

  ProxyState({
    this.nodes = const [],
    this.selectedNode,
    this.isLoading = false,
    this.error,
  });

  ProxyState copyWith({
    List<ProxyNode>? nodes,
    ProxyNode? selectedNode,
    bool? isLoading,
    String? error,
  }) {
    return ProxyState(
      nodes: nodes ?? this.nodes,
      selectedNode: selectedNode ?? this.selectedNode,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ProxyNotifier extends StateNotifier<ProxyState> {
  final Ref ref;

  ProxyNotifier(this.ref) : super(ProxyState());

  Future<void> fetchNodes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiServiceProvider);
      // Fetch raw data
      final List<dynamic> rawData = await api.fetchSubscribe();

      // Parse to ProxyNode
      final nodes = rawData.map((e) => ProxyNode.fromJson(e)).toList();

      ProxyNode? selected = state.selectedNode;
      if (nodes.isNotEmpty && selected == null) {
        selected = nodes.first; // Default select first
      }

      state = state.copyWith(
        nodes: nodes,
        selectedNode: selected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectNode(ProxyNode node) {
    state = state.copyWith(selectedNode: node);
  }

  void updateNodes(List<ProxyNode> nodes) {
    ProxyNode? selected = state.selectedNode;
    if (nodes.isNotEmpty && selected == null) {
      selected = nodes.first;
    }
    state = state.copyWith(
      nodes: nodes,
      selectedNode: selected,
      isLoading: false,
      error: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }
}

final proxyProvider = StateNotifierProvider<ProxyNotifier, ProxyState>((ref) {
  return ProxyNotifier(ref);
});
