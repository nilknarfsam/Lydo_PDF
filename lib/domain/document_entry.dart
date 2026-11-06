/// Um PDF da biblioteca, com a posição onde o usuário parou.
class DocumentEntry {
  const DocumentEntry({
    required this.id,
    required this.name,
    required this.path,
    required this.addedAt,
    required this.lastOpenedAt,
    this.pageCount = 0,
    this.lastPage = 1,
    this.viewMatrix,
    this.sizeBytes = 0,
    this.favorite = false,
    this.lastLayoutHorizontal = false,
  });

  /// Impressão digital do conteúdo (não do caminho): o mesmo PDF
  /// importado duas vezes cai na mesma entrada e mantém o progresso.
  final String id;
  final String name;

  /// Cópia do PDF dentro da pasta do app.
  final String path;
  final DateTime addedAt;
  final DateTime lastOpenedAt;
  final int pageCount;
  final int lastPage;

  /// Matriz de zoom/rolagem do leitor (16 valores), para voltar
  /// exatamente ao ponto da página, não só ao topo dela.
  final List<double>? viewMatrix;
  final int sizeBytes;
  final bool favorite;

  /// Modo de rolagem em que [viewMatrix] foi salva (a matriz só serve nele).
  final bool lastLayoutHorizontal;

  /// Progresso de 0 a 1 (página atual / total).
  double get progress => pageCount <= 0 ? 0 : (lastPage / pageCount).clamp(0, 1);

  bool get hasStarted => pageCount > 0;

  DocumentEntry copyWith({
    String? name,
    DateTime? lastOpenedAt,
    int? pageCount,
    int? lastPage,
    List<double>? viewMatrix,
    int? sizeBytes,
    bool? favorite,
    bool? lastLayoutHorizontal,
  }) {
    return DocumentEntry(
      id: id,
      name: name ?? this.name,
      path: path,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pageCount: pageCount ?? this.pageCount,
      lastPage: lastPage ?? this.lastPage,
      viewMatrix: viewMatrix ?? this.viewMatrix,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      favorite: favorite ?? this.favorite,
      lastLayoutHorizontal: lastLayoutHorizontal ?? this.lastLayoutHorizontal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'addedAt': addedAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
        'pageCount': pageCount,
        'lastPage': lastPage,
        if (viewMatrix != null) 'viewMatrix': viewMatrix,
        'sizeBytes': sizeBytes,
        'favorite': favorite,
        'lastLayoutHorizontal': lastLayoutHorizontal,
      };

  factory DocumentEntry.fromJson(Map<String, dynamic> json) {
    final matrix = json['viewMatrix'] as List<dynamic>?;
    return DocumentEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      pageCount: json['pageCount'] as int? ?? 0,
      lastPage: json['lastPage'] as int? ?? 1,
      viewMatrix: matrix?.map((e) => (e as num).toDouble()).toList(),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      favorite: json['favorite'] as bool? ?? false,
      lastLayoutHorizontal: json['lastLayoutHorizontal'] as bool? ?? false,
    );
  }
}
