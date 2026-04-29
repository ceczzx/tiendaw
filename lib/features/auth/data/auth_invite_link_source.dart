import 'package:app_links/app_links.dart';

class AuthInviteLinkSource {
  AuthInviteLinkSource([AppLinks? appLinks])
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  Future<Uri?> getInitialInviteLink() async {
    final initialLink = await _appLinks.getInitialLink();
    if (!isInviteLink(initialLink)) {
      return null;
    }

    return initialLink;
  }

  Stream<Uri> get inviteLinkStream =>
      _appLinks.uriLinkStream.where(isInviteLink);

  bool isInviteLink(Uri? uri) {
    if (uri == null) {
      return false;
    }

    return normalizeInviteLink(uri).queryParameters['type'] == 'invite';
  }

  Uri normalizeInviteLink(Uri uri) {
    // Supabase puede devolver tokens dentro del hash; los convertimos
    // temporalmente a query params para leer `type=invite` de forma uniforme.
    final rawUri = uri.toString();
    final normalizedUri =
        uri.hasQuery
            ? rawUri.replaceAll('#', '&')
            : rawUri.replaceAll('#', '?');
    return Uri.parse(normalizedUri);
  }
}
