---
layout: post
title: "JASPIC security for a JAX-RS endpoint using BASIC authentication"
date: 2017-02-07
tags:
- JASPIC
- JAX-RS
- BASIC authentication
- Glassfish
---
## Background
The Java Authentication Service Provider Interface For Containers (JASPIC)
allows message authentication modules to be integrated in Java EE containers.
The specification ([JSR-196][jsr-196]), implemented in Java EE 6 and 7, provides
a standard interface for securing applications. For Java EE 8, a different
interface, more suitable for cloud/PaaS environments, will be used: The Java EE
Security API ([JSR-375][jsr-375]).

## Source code
The complete source code of the example used in this post is available on the
weblog's [Github repo][guzman-github], in the `jaspic-basic` folder.

The integration tests are run on a local installation of Glassfish 4.1 (web
profile) and do not use Cargo or Arquillian. The installation and configuration
of Glassfish is done by Maven.

Java 8 and Apache Maven 3 are required to run the code.

## Components
The components will be presented in a top-down flow, starting from the
web application.
The user credentials will be passed to the container for authentication in the
header section of the HTTP request to the JAX-RS endpoint.

### JAX-RS endpoint

The web application has a class annotated to serve as a JAX-RS endpoint
`Ahoy.class`, with one of its methods restricted to users who have been granted
the `USER` role. Apart from the `@RolesAllowed` annotation, no additional Java
code is required to secure the web application, as the authentication and
authorisation are done by the container.
```java
@Path("/")
public class Ahoy {

  @GET
  @RolesAllowed("USER")
  @Produces("text/plain")
  public Response doGet() {
    return Response.ok("method doGet invoked").build();
  }
}
```
In the `web.xml` deployment descriptor we specify that the authentication
mechanism will be HTTP Basic, as well as the name of the realm containing the
user credentials and the role names allowed to access the restricted resources
of the web application.
```xml
  <security-constraint>
    <display-name>UserConstraint</display-name>
    <web-resource-collection>
      <web-resource-name>jaspic-basic-web</web-resource-name>
      <description/>
      <url-pattern>/jaspic-basic-web/rest</url-pattern>
    </web-resource-collection>
  </security-constraint>
  <login-config>
    <auth-method>BASIC</auth-method>
    <realm-name>testFileRealm</realm-name>
  </login-config>
  <security-role>
    <role-name>USER</role-name>
  </security-role>
```
The scope of security roles does not depend on how users are managed in a
realm (in this example `testFileRealm`) and is specific to the application.
The transition from the concept of user to security role is vendor-specific.
In Glassfish, users can be clustered in groups. The mapping between groups (or
users) and security roles is done in the `glassfish-web.xml` deployment
descriptor. In this example, users that belong to the `USER` *group* will be
allocated the `USER` *role*.

We also specify in this file the name of the message security provider (in
this case, the server authentication module, as known to the application
server: `TestSAM`).

```xml
<glassfish-web-app error-url="" httpservlet-security-provider="TestSAM">
  <security-role-mapping>
    <role-name>USER</role-name>
    <group-name>USER</group-name>
  </security-role-mapping>
</glassfish-web-app>
```

### Server Authentication Module (SAM)
The second component is the Server Authentication Module (SAM). This module
contains the class `HeaderBasicAuthModule` that implements the JASPIC interface
`ServerAuthModule` and will be called by the JASPIC-compliant server at
different stages of the message processing pathway (`validateRequest` and
`secureResponse` stages).

The authentication takes place in the `validateRequest` stage of the pathway,
before being dispatched to the JAX-RS endpoint. The authentication module
obtains the credentials of the user from the HTTP header `Authorization`.
```java
HttpServletRequest request = (HttpServletRequest) msgInfo.getRequestMessage();
String header = request.getHeader("Authorization");
```

For a Basic authentication mechanism, clients must provide the credentials in
the `Authorization` header with a value of `Basic (base64-encoded-credentials)`.
In this example the credentials are in the format *username:password* and then
encoded. After checking that the `Authorization` header is present and has the
right format, the credentials are decoded.
```java
header = header.substring(6).trim();

// Decode and parse the authorization header
byte[] headerBytes = header.getBytes(Charset.forName("UTF-8"));
byte[] decBytes = Base64.getDecoder().decode(headerBytes);
String decoded = new String(decBytes, Charset.forName("UTF-8"));
```
Then the credentials are passed to the container in an array of `Callback` for
authentication. The web container will validate the credentials against the
realm as set in `web.xml`.
```java
int colon = decoded.indexOf(':');
String username = decoded.substring(0, colon);

// use the callback to ask the container to validate the password      
PasswordValidationCallback pwValCallback = new PasswordValidationCallback(
  subj, username, decoded.substring(colon + 1).toCharArray());

try {
  handler.handle(new Callback[]{passwordValidationCallback});
  pwValCallback.clearPassword();
} catch (IOException | UnsupportedCallbackException ex) {
  AuthException ae = new AuthException();
  ae.initCause(ex);
  throw ae;
}
```
If the credentials provided are valid, then the module must return
`AuthStatus.SUCCESS`. Otherwise, it must return `AuthStatus.SEND_FAILURE` if the
response message can be populated with for example HTTP return code such as
`406 NOT ACCEPTABLE` or `403 FORBIDDEN`. If no return code can be provided, then
an `AuthException` must be returned.
```java
// Evaluate whether not secure connections are allowed against policy
try {
  if (!req.isSecure() && !allowNotSecure) {
    resp.sendError(HttpURLConnection.HTTP_NOT_ACCEPTABLE);
    return AuthStatus.SEND_FAILURE;
  }

  if (!requestPolicy.isMandatory()) {

    final String userName = readAuthenticationHeader(msgInfo, clientSubject);

    if (null == userName) {
      resp.sendError(HttpURLConnection.HTTP_FORBIDDEN);
      return AuthStatus.SEND_FAILURE;
    }

    return AuthStatus.SUCCESS;

  } else {
    return AuthStatus.SUCCESS;
  }
} catch (IOException ex) {
  AuthException ae = new AuthException();
  ae.initCause(ex);
  throw ae;
}
```
### Glassfish
The SAM must be added to Glassfish's classpath (copy the jar with the SAM to the
`lib` folder of Glassfish) and then configured for the domain. At the moment,
HttpServlet and SOAP layers are supported. The name of the message security
provider is the one specified in `glassfish-web.xml`.
```
asadmin create-message-security-provider \
--layer HttpServlet \
--providertype server \
--isdefaultprovider=false \
--property allow.notsecure=true \
--classname guzman.weblog.jaspic.basic.HeaderBasicAuthModule \
--target server \
TestSAM
```
This example uses a simple file realm, as configured in `web.xml`.
```
asadmin create-auth-realm \
--classname com.sun.enterprise.security.auth.realm.file.FileRealm \
--property file=${path-to-keyfile}/test-keyfile:jaas-context=fileRealm \
--target server \
testFileRealm
```
The file realm in Glassfish uses a text file to store credentials, each row
contains three fields separated by a semicolon. The last field is the group
that the user belongs to. This group name is the one used in the mapping to
role names in `glassfish-web.xml`.
```
testUser;{SSHA256}3jjWMzd6kl7Vfm1AC+Wn8Rno9fEcnqUIU87zdjr2B9Eu0kTdCg3UCw==;USER
```
## Testing
The integration tests use Jersey Client to call the JAX-RS endpoint (`Ahoy`).
configured to accept requests on `http://localhost:8081/jaspic-basic-web/rest`.

The SAM sets a return code of `HttpURLConnection.HTTP_FORBIDDEN` in the
response if the `Authorization: Basic` header is missing or if the credentials
supplied are invalid. In Jersey Client, the 403 return code is captured as
`ForbiddenException.class`.
```java
@Test
public void testDoGetNoCredentials() {
  ClientConfig config = new ClientConfig();
  final Client restClient = ClientBuilder.newClient(config);
  WebTarget target = restClient
      .target("http://localhost:8081/jaspic-basic-web/rest");
  assertThrows(ForbiddenException.class,
      () -> {
        target.request(MediaType.TEXT_PLAIN_TYPE).get(String.class);
      }
  );
}

@Test
public void testDoGetInvalidPassword() {
  ClientConfig config = new ClientConfig();
  final Client restClient = ClientBuilder.newClient(config);
  WebTarget target = restClient
      .target("http://localhost:8081/jaspic-basic-web/rest");
  // Send testUser:invalidPassword
  assertThrows(ForbiddenException.class,
      () -> {
        target.request(MediaType.TEXT_PLAIN_TYPE)
            .header("Authorization", "Basic dGVzdFVzZXI6aW52YWxpZFBhc3N3b3Jk")
            .get(String.class);
      }
  );
}
```
When the `Authorization: Basic` header is supplied with the correct credentials,
the SAM validates the request, dispatching the call to the web container as
coming from the role `USER`.
```java
@Test
public void testDoGetValidCredentials() {
  ClientConfig config = new ClientConfig();
  final Client restClient = ClientBuilder.newClient(config);
  WebTarget target = restClient
      .target("http://localhost:8081/jaspic-basic-web/rest");
  // Send testUser:testPassword
  String result = target.request(MediaType.TEXT_PLAIN_TYPE)
          .header("Authorization", "Basic dGVzdFVzZXI6dGVzdFBhc3N3b3Jk")
          .get(String.class);
  String expResult = "method doGet invoked";
  assertEquals(result, expResult);
}
```

## Further reading
- [JSR 196: Java Authentication Service Provider Interface For Containers][jsr-196]
- [JSR 375: Java EE Security API][jsr-375]
- [JASPIC by Arjan Tims][jaspic-zeef]
- [Adding Authentication Mechanisms to the GlassFish Servlet Container][techtips-auth]

[jsr-196]: https://www.jcp.org/en/jsr/detail?id=196
[jsr-375]: https://www.jcp.org/en/jsr/detail?id=375
[jaspic-zeef]: https://jaspic.zeef.com/arjan.tijms
[guzman-github]: https://github.com/david-guzman/weblog-examples
[techtips-auth]: https://blogs.oracle.com/enterprisetechtips/entry/adding_authentication_mechanisms_to_the
