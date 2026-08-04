import 'web_launcher_stub.dart'
    if (dart.library.html) 'web_launcher_html.dart';

void openUrlInBrowser(String url) {
  openWebUrl(url);
}
