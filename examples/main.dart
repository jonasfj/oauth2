import 'dart:io';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'dart:async';

// These URLs are endpoints that are provided by the authorization
// server. They're usually included in the server's documentation of its
// OAuth2 API.
final authorizationEndpoint =
    Uri.parse("http://example.com/oauth2/authorization");
final tokenEndpoint = Uri.parse("http://example.com/oauth2/token");

// The authorization server will issue each client a separate client
// identifier and secret, which allows the server to tell which client
// is accessing it. Some servers may also have an anonymous
// identifier/secret pair that any client may use.
//
// Note that clients whose source code or binary executable is readily
// available may not be able to make sure the client secret is kept a
// secret. This is fine; OAuth2 servers generally won't rely on knowing
// with certainty that a client is who it claims to be.
final identifier = "my client identifier";
final secret = "my client secret";

// This is a URL on your application's server. The authorization server
// will redirect the resource owner here once they've authorized the
// client. The redirection will include the authorization code in the
// query parameters.
//
// In this example we use localhost, that only really works if you're developing
// an application that runs on the users computer.
final redirectUrl = Uri.parse("http://localhost:8080");

/// A file in which the users credentials are stored persistently. If the server
/// issues a refresh token allowing the client to refresh outdated credentials,
/// these may be valid indefinitely, meaning the user never has to
/// re-authenticate.
final credentialsFile = new File("~/.myapp/credentials.json");

/// Either load an OAuth2 client from saved credentials or authenticate a new
/// one.
Future<oauth2.Client> getClient() async {
  var exists = await credentialsFile.exists();

  // If the OAuth2 credentials have already been saved from a previous run, we
  // just want to reload them.
  if (exists) {
    var credentials =
        new oauth2.Credentials.fromJson(await credentialsFile.readAsString());
    return new oauth2.Client(credentials,
        identifier: identifier, secret: secret);
  }

  // If we don't have OAuth2 credentials yet, we need to get the resource owner
  // to authorize us. We're assuming here that we're a command-line application.
  var grant = new oauth2.AuthorizationCodeGrant(
      identifier, authorizationEndpoint, tokenEndpoint,
      secret: secret);

  // Redirect the resource owner to the authorization URL. This will be a URL on
  // the authorization server (authorizationEndpoint with some additional query
  // parameters). Once the resource owner has authorized, they'll be redirected
  // to `redirectUrl` with an authorization code.
  print('Please open this URL and login:');
  print(grant.getAuthorizationUrl(redirectUrl).toString());

  // Next we setup a server and listen on localhost port 8080, which match the
  // redirectUrl we have, where we wait for the first request.
  final server = await HttpServer.bind('localhost', 8080);
  final request = await server.first;

  // Once the user is redirected to `redirectUrl`, pass the query parameters to
  // the AuthorizationCodeGrant. It will validate them and extract the
  // authorization code to create a new Client.
  final client = await grant.handleAuthorizationResponse(
    request.requestedUri.queryParameters,
  );

  // Ignore the rest of the request, and send a quick response.
  await request.drain();
  request.response.statusCode = 200;
  request.response.write('<b>Login success</b>');
  await request.response.close();

  // Now close the server as we don't need it anymore.
  await server.close(force: true);

  return client;
}

main() async {
  var client = await getClient();

  // Once you have a Client, you can use it just like any other HTTP client.
  var result = client.read("http://example.com/protected-resources.txt");

  // Once we're done with the client, save the credentials file. This ensures
  // that if the credentials were automatically refreshed while using the
  // client, the new credentials are available for the next run of the
  // program.
  await credentialsFile.writeAsString(client.credentials.toJson());

  print(result);
}
