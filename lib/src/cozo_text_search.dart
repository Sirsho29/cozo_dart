import 'cozo_database.dart';
import 'cozo_result.dart';

// ──────────── FTS Tokenizers ────────────

/// Tokenizer strategy for full-text search indexing.
enum FtsTokenizer {
  /// No tokenization — the entire field value is a single token.
  raw('Raw'),

  /// Splits on whitespace and punctuation. Suitable for most Latin-script
  /// languages.
  simple('Simple'),

  /// CJK-aware tokenization using the Cangjie library.
  /// Use for Chinese, Japanese, and Korean text.
  cangjie('Cangjie');

  final String value;
  const FtsTokenizer(this.value);
}

// ──────────── FTS Filters ────────────

/// A filter applied during FTS tokenization.
///
/// Filters are applied in order after tokenization. Common patterns:
///
/// ```dart
/// filters: [
///   FtsLowercase(),
///   FtsAlphaNumOnly(),
///   FtsStemmer('english'),
///   FtsStopwords('en'),
/// ]
/// ```
sealed class FtsFilter {
  /// Serialize this filter to CozoScript syntax.
  String toCozoScript();
}

/// Converts all tokens to lowercase.
class FtsLowercase extends FtsFilter {
  @override
  String toCozoScript() => 'Lowercase';
}

/// Removes non-alphanumeric characters from tokens.
class FtsAlphaNumOnly extends FtsFilter {
  @override
  String toCozoScript() => 'AlphaNumOnly';
}

/// Folds Unicode characters to ASCII equivalents (e.g., ñ → n, ü → u).
class FtsAsciiFolding extends FtsFilter {
  @override
  String toCozoScript() => 'AsciiFolding';
}

/// Applies language-specific stemming (e.g., "running" → "run").
///
/// Supported languages include: `'arabic'`, `'danish'`, `'dutch'`,
/// `'english'`, `'finnish'`, `'french'`, `'german'`, `'greek'`,
/// `'hungarian'`, `'italian'`, `'norwegian'`, `'portuguese'`,
/// `'romanian'`, `'russian'`, `'spanish'`, `'swedish'`, `'tamil'`,
/// `'turkish'`.
class FtsStemmer extends FtsFilter {
  final String language;
  FtsStemmer(this.language);

  @override
  String toCozoScript() => "Stemmer('$language')";
}

/// Removes common stopwords for a language (e.g., "the", "is", "at").
///
/// Use ISO 639-1 codes: `'en'`, `'fr'`, `'de'`, `'es'`, etc.
class FtsStopwords extends FtsFilter {
  final String language;
  FtsStopwords(this.language);

  @override
  String toCozoScript() => "Stopwords('$language')";
}

// ──────────── CozoTextSearch ────────────

/// Full-text search (FTS) and locality-sensitive hashing (LSH) operations
/// for CozoDB.
///
/// CozoDB natively supports:
/// - **FTS indices** with BM25 ranking for keyword/relevance search
/// - **LSH indices** with MinHash for near-duplicate / similarity detection
///
/// ## Full-Text Search
///
/// ```dart
/// final textSearch = CozoTextSearch(db);
///
/// // Create a relation with text columns
/// await db.query(':create articles {id: Int => title: String, body: String}');
///
/// // Create an FTS index on the body column
/// await textSearch.createIndex(
///   'articles', 'articles_body_fts',
///   extractor: 'body',
///   tokenizer: FtsTokenizer.simple,
///   filters: [FtsLowercase(), FtsStemmer('english'), FtsStopwords('en')],
/// );
///
/// // Search
/// final results = await textSearch.search(
///   'articles', 'articles_body_fts',
///   queryText: 'graph database performance',
///   bindFields: ['id', 'title'],
///   k: 10,
/// );
/// ```
///
/// ## LSH (Locality-Sensitive Hashing)
///
/// ```dart
/// // Create an LSH index for near-duplicate detection
/// await textSearch.createLSHIndex(
///   'articles', 'articles_lsh',
///   extractor: 'body',
///   targetThreshold: 0.5,
/// );
///
/// // Find similar documents
/// final similar = await textSearch.similaritySearch(
///   'articles', 'articles_lsh',
///   queryText: 'some document text...',
///   bindFields: ['id', 'title'],
///   k: 5,
/// );
/// ```
///
/// ## Hybrid Search
///
/// Both FTS and LSH queries return Datalog relations and can be combined
/// with other conditions using [searchWithConditions]:
///
/// ```dart
/// final results = await textSearch.searchWithConditions(
///   'articles', 'articles_body_fts',
///   queryText: 'machine learning',
///   bindFields: ['id', 'body'],
///   joinConditions:
///     '*articles{ id, author_id },'
///     ' *authors{ author_id, name },'
///     ' name == "Alice"',
///   outputFields: ['body', 'name', 'score'],
/// );
/// ```
class CozoTextSearch {
  final CozoDatabase db;

  const CozoTextSearch(this.db);

  // ──────────── FTS Index Management ────────────

  /// Create a full-text search index on a stored relation.
  ///
  /// - [relation]: Name of the stored relation.
  /// - [indexName]: Name for the new FTS index.
  /// - [extractor]: Column name containing text to index.
  /// - [tokenizer]: Tokenization strategy. Defaults to [FtsTokenizer.simple].
  /// - [filters]: Ordered list of token filters applied after tokenization.
  ///
  /// ```dart
  /// await textSearch.createIndex(
  ///   'posts', 'posts_title_fts',
  ///   extractor: 'title',
  ///   filters: [FtsLowercase(), FtsAlphaNumOnly()],
  /// );
  /// ```
  Future<CozoResult> createIndex(
    String relation,
    String indexName, {
    required String extractor,
    FtsTokenizer tokenizer = FtsTokenizer.simple,
    List<FtsFilter> filters = const [],
  }) async {
    final buf = StringBuffer();
    buf.write('::fts create $relation:$indexName {');
    buf.write(' extractor: $extractor,');
    buf.write(' tokenizer: ${tokenizer.value}');
    if (filters.isNotEmpty) {
      buf.write(
          ', filters: [${filters.map((f) => f.toCozoScript()).join(', ')}]');
    }
    buf.write(' }');
    return db.query(buf.toString());
  }

  /// Drop a full-text search index.
  Future<CozoResult> dropIndex(String relation, String indexName) async {
    return db.query('::fts drop $relation:$indexName');
  }

  // ──────────── FTS Search ────────────

  /// Search for documents matching a text query using BM25 ranking.
  ///
  /// - [relation]: Name of the indexed relation.
  /// - [indexName]: Name of the FTS index.
  /// - [queryText]: The search query string.
  /// - [bindFields]: Columns from the relation to include in results.
  /// - [k]: Maximum number of results to return. Defaults to 10.
  /// - [bindScore]: Output column name for BM25 relevance scores.
  /// - [filter]: CozoScript boolean expression for pre-filtering.
  ///
  /// Returns a [CozoResult] with [bindFields] plus a score column,
  /// ordered by relevance (highest score first).
  ///
  /// ```dart
  /// final results = await textSearch.search(
  ///   'articles', 'articles_fts',
  ///   queryText: 'vector database',
  ///   bindFields: ['id', 'title', 'body'],
  ///   k: 20,
  /// );
  /// ```
  Future<CozoResult> search(
    String relation,
    String indexName, {
    required String queryText,
    required List<String> bindFields,
    int k = 10,
    String bindScore = 'score',
    String? filter,
  }) async {
    final searchParams = StringBuffer('query: \$_q, k: $k');
    searchParams.write(', bind_score: $bindScore');
    if (filter != null) searchParams.write(', filter: $filter');

    final outputFields = [...bindFields, bindScore];

    return db.query(
      '?[${outputFields.join(', ')}] := '
      '~$relation:$indexName{ ${bindFields.join(', ')} '
      '| $searchParams }',
      params: {'_q': queryText},
    );
  }

  /// Search with additional Datalog join conditions (hybrid FTS).
  ///
  /// Combines full-text relevance with structured relational filters,
  /// graph traversals, or aggregations via CozoDB's Datalog engine.
  ///
  /// The [joinConditions] are appended after the FTS search clause.
  /// Variables bound in [bindFields] and [bindScore] are available
  /// for use in the join conditions.
  ///
  /// ```dart
  /// final results = await textSearch.searchWithConditions(
  ///   'articles', 'articles_fts',
  ///   queryText: 'machine learning',
  ///   bindFields: ['id', 'body'],
  ///   joinConditions:
  ///     '*articles{ id, author_id, published_at },'
  ///     ' *authors{ author_id, name },'
  ///     ' published_at > 1700000000',
  ///   outputFields: ['body', 'name', 'score'],
  /// );
  /// ```
  Future<CozoResult> searchWithConditions(
    String relation,
    String indexName, {
    required String queryText,
    required List<String> bindFields,
    required String joinConditions,
    required List<String> outputFields,
    int k = 10,
    String bindScore = 'score',
    Map<String, dynamic>? additionalParams,
  }) async {
    final searchParams = StringBuffer('query: \$_q, k: $k');
    searchParams.write(', bind_score: $bindScore');

    final params = <String, dynamic>{
      '_q': queryText,
      ...?additionalParams,
    };

    final script = '?[${outputFields.join(', ')}] := '
        '~$relation:$indexName{ ${bindFields.join(', ')} '
        '| $searchParams }, $joinConditions';

    return db.query(script, params: params);
  }

  // ──────────── LSH Index Management ────────────

  /// Create an LSH (Locality-Sensitive Hashing) index for near-duplicate
  /// and similarity detection using MinHash / Jaccard similarity.
  ///
  /// - [relation]: Name of the stored relation.
  /// - [indexName]: Name for the new LSH index.
  /// - [extractor]: Column name containing text to hash.
  /// - [tokenizer]: Tokenization strategy. Defaults to [FtsTokenizer.simple].
  /// - [filters]: Token filters applied after tokenization.
  /// - [nPerm]: Number of permutations for MinHash. Higher = more accurate
  ///   but slower. Defaults to 200.
  /// - [targetThreshold]: Jaccard similarity threshold (0.0 to 1.0).
  ///   Documents above this threshold are considered similar. Defaults to 0.7.
  /// - [nGram]: Character n-gram size for shingling. Defaults to 3.
  /// - [falsePositiveWeight]: Weight for false positives in optimization.
  /// - [falseNegativeWeight]: Weight for false negatives in optimization.
  ///
  /// ```dart
  /// await textSearch.createLSHIndex(
  ///   'articles', 'articles_lsh',
  ///   extractor: 'body',
  ///   targetThreshold: 0.5,
  ///   nGram: 3,
  /// );
  /// ```
  Future<CozoResult> createLSHIndex(
    String relation,
    String indexName, {
    required String extractor,
    FtsTokenizer tokenizer = FtsTokenizer.simple,
    List<FtsFilter> filters = const [],
    int nPerm = 200,
    double targetThreshold = 0.7,
    int nGram = 3,
    double falsePositiveWeight = 1.0,
    double falseNegativeWeight = 1.0,
  }) async {
    final buf = StringBuffer();
    buf.write('::lsh create $relation:$indexName {');
    buf.write(' extractor: $extractor,');
    buf.write(' tokenizer: ${tokenizer.value}');
    if (filters.isNotEmpty) {
      buf.write(
          ', filters: [${filters.map((f) => f.toCozoScript()).join(', ')}]');
    }
    buf.write(', n_perm: $nPerm');
    buf.write(', target_threshold: $targetThreshold');
    buf.write(', n_gram: $nGram');
    buf.write(', false_positive_weight: $falsePositiveWeight');
    buf.write(', false_negative_weight: $falseNegativeWeight');
    buf.write(' }');
    return db.query(buf.toString());
  }

  /// Drop an LSH index.
  Future<CozoResult> dropLSHIndex(String relation, String indexName) async {
    return db.query('::lsh drop $relation:$indexName');
  }

  // ──────────── LSH Search ────────────

  /// Find similar documents using LSH (Jaccard similarity via MinHash).
  ///
  /// - [relation]: Name of the indexed relation.
  /// - [indexName]: Name of the LSH index.
  /// - [queryText]: Text to find similar documents for.
  /// - [bindFields]: Columns from the relation to include in results.
  /// - [k]: Maximum number of results. Defaults to 10.
  /// - [bindScore]: Output column name for similarity scores.
  ///
  /// ```dart
  /// final similar = await textSearch.similaritySearch(
  ///   'articles', 'articles_lsh',
  ///   queryText: 'CozoDB is a graph database with Datalog queries...',
  ///   bindFields: ['id', 'title'],
  ///   k: 5,
  /// );
  /// ```
  Future<CozoResult> similaritySearch(
    String relation,
    String indexName, {
    required String queryText,
    required List<String> bindFields,
    int k = 10,
  }) async {
    final searchParams = 'query: \$_q, k: $k';

    return db.query(
      '?[${bindFields.join(', ')}] := '
      '~$relation:$indexName{ ${bindFields.join(', ')} '
      '| $searchParams }',
      params: {'_q': queryText},
    );
  }

  /// Find similar documents with additional Datalog join conditions.
  Future<CozoResult> similaritySearchWithConditions(
    String relation,
    String indexName, {
    required String queryText,
    required List<String> bindFields,
    required String joinConditions,
    required List<String> outputFields,
    int k = 10,
    Map<String, dynamic>? additionalParams,
  }) async {
    final searchParams = 'query: \$_q, k: $k';

    final params = <String, dynamic>{
      '_q': queryText,
      ...?additionalParams,
    };

    final script = '?[${outputFields.join(', ')}] := '
        '~$relation:$indexName{ ${bindFields.join(', ')} '
        '| $searchParams }, $joinConditions';

    return db.query(script, params: params);
  }
}
