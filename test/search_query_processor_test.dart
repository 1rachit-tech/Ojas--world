import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/features/discovery/search/query_processor.dart';
import 'package:ojas_app/features/discovery/search/domain/search_models.dart';

void main() {
  const processor = SearchQueryProcessor();

  test('normalizes mixed Hindi and Latin whitespace', () {
    final query = processor.process('  बारिश   Song  ');

    expect(query.normalized, 'बारिश song');
    expect(query.language, 'hi-Latn-mixed');
    expect(query.intent, SearchEntityType.sound);
    expect(query.aliases, contains('barish'));
    expect(query.aliases, contains('song'));
  });

  test('supports handle and hashtag aliases', () {
    final handle = processor.process('@RachitRam');
    expect(handle.intent, SearchEntityType.person);
    expect(handle.aliases, contains('rachitram'));

    final hashtag = processor.process('#क्रिकेट');
    expect(hashtag.intent, SearchEntityType.hashtag);
    expect(hashtag.aliases, contains('क्रिकेट'));
    expect(hashtag.aliases.any((value) => value.contains('kriket')), isTrue);
  });

  test('finds close typo candidates', () {
    expect(
      SearchQueryProcessor.didYouMean('baris', const <String>['barish', 'cricket']),
      'barish',
    );
  });
}
