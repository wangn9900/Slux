class ProxyNode {
  final String name;
  final String type; // vmess, vless, trojan, shadowsocks
  final String server;
  final int port;
  final String uuid; // or password
  final int alterId;
  final String cipher;
  final String network; // tcp, ws, grpc
  final Map<String, dynamic> tls;

  ProxyNode({
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.uuid = '',
    this.alterId = 0,
    this.cipher = '',
    this.network = 'tcp',
    this.tls = const {},
  });

  factory ProxyNode.fromJson(Map<String, dynamic> json) {
    return ProxyNode(
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'vmess',
      server: json['server'] ?? '',
      port: int.tryParse(json['port'].toString()) ?? 443,
      uuid: json['uuid'] ?? json['password'] ?? '',
      alterId: int.tryParse(json['alterId'].toString()) ?? 0,
      cipher: json['cipher'] ?? '',
      network: json['network'] ?? 'tcp',
      tls: json['tls'] ?? {},
    );
  }
}
