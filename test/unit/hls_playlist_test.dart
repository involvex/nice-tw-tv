import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/watch/data/hls_resolver.dart';

void main() {
  test('parseMasterPlaylist extracts named variants', () {
    const body = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p60",NAME="720p60",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.4D402A,mp4a.40.2",VIDEO="chunked"
https://example.com/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,CODECS="avc1.4D401F,mp4a.40.2",VIDEO="720p60"
https://example.com/720.m3u8
''';
    final variants = HlsResolver.parseMasterPlaylist(
      body,
      Uri.parse('https://usher.example/master.m3u8'),
    );
    expect(variants.map((v) => v.name), ['1080p60', '720p60']);
    expect(variants.first.height, 1080);
    expect(variants.first.url.toString(), 'https://example.com/1080.m3u8');
  });
}
