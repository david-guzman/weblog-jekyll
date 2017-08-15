---
layout: post
title: "Testing JSR 375 BASIC authentication in a Servlet (file realm)"
date: 2017-08-07
tags:
- JSR 375
- Servlet
- BASIC authentication
---

## Background

Java EE 8 (JSR 366), now with its specification request in the Final Approval
Ballot stage, is set to be released by the end of 2017.

This version adds a new specification; the [Java EE Security API (JSR 375)][jsr-375]. This API aims
at standardising the configuration of authentication mechanisms and identity stores using CDI,
offering developers an alternative to enable security in applications, independent from
vendor-specific configuration.

## Source code

The complete source code of the example used in this post is available on the
weblog's [Github repo][guzman-github], in the `servlet-jsr375/servlet-basic-file` folder.

The integration tests are run against a local installation of Glassfish 4.1.1 (web
profile), and do not use Arquillian or Cargo. The configuration of Glassfish is
done by Maven.

Java 8 and Apache Maven 3 are required to run the sample application.

## Java EE Security API

The new Java EE Security API (RI Soteria) aims at making the configuration
of applications as simple and portable as possible, offering developers an API that integrates
elements from JASPIC and Servlet API.

The specification describes the following interfaces and contracts:

**HttpAuthenticationMechanism**
: Specific to the Servlet container, this interface defines methods for authentication of callers
  against a store of identity information of users.

**IdentityStore**
: Abstraction of a database or directory of users. It provides methods for verification of
  credentials and for obtaining information about the caller.

**SecurityContext**
: Available in the Servlet and EJB containers, this interface provides methods for testing and
  controlling access to application resources.

The sample application covered in this post makes use of `HttpAuthenticationMechanism` from the Java
EE Security API, while relying on the identity store and security context from the application
server, in this case Glassfish.

For applications running in Java EE 7 servers, the API and the reference implementation (Soteria)
need to be packaged in the web application. Adding Soteria to the POM will include the API as
dependency.

```xml
<dependency>
  <groupId>org.glassfish.soteria</groupId>
  <artifactId>javax.security.enterprise</artifactId>
  <version>${dep.soteria.version}</version>
</dependency>
```

As the version of Soteria used in this example is 1.0-b11-SNAPSHOT, the snapshots repository needs
to be enabled in the POM.

```xml
<repositories>
  <repository>
    <id>Soteria Snapshots</id>
    <url>https://maven.java.net/content/repositories/snapshots/</url>
    <snapshots>
      <enabled>true</enabled>
    </snapshots>
  </repository>
</repositories>
```

## @BasicAuthenticationMechanismDefinition

The reference implementation of `HttpAuthenticationMechanism` define mechanisms for HTTP Basic and
HTTP Form Based authentication equivalent to the ones defined in Servlet 3.1. Instead of using
`<login-conf>` section in `web.xml` to configure the authentication mechanism and realm name, as
done by the Servlet container, with the Java Security API is done with annotations.

The built-in authentication mechanisms defined in the specification are `@ApplicationScoped` CDI
beans. For HTTP Basic authentication mechanism, the configuration is done with the
`@BasicAuthenticationMechanismDefinition` annotation.


```java
@Retention(RUNTIME)
@Target(TYPE)
public @interface BasicAuthenticationMechanismDefinition {

  String realmName() default "";
}
```

The value of `realmName()` is used for the `WWW-Authenticate` HTTP header. It does not configure the
identity store to be used by the authentication mechanism.

There is no `web.xml` in this sample application. All the security configuration is done with
annotations. 

```java
@WebServlet(urlPatterns = "/basicServlet")
@DeclareRoles({"USER"})
@BasicAuthenticationMechanismDefinition(realmName = "www-authenticate-realm")
@ServletSecurity(@HttpConstraint(rolesAllowed = "USER"))
public class BasicServlet extends HttpServlet {

  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp)
    throws ServletException, IOException {

    String webName = null;
    if (req.getUserPrincipal() != null) {
      webName = req.getUserPrincipal().getName();
    }

    resp.getWriter().write("Caller " + webName + " in role USER");
  }
  
}
```

The Java EE Security API specification defines built-in identity stores for database and LDAP types,
but in this example, the verification of the caller's credentials is done against the *file realm*
available in Glassfish.

## Testing

The tests use an instance of `HttpURLConnection` to call the servlet (`BasicServlet`) on
*http://localhost:8081/servlet-basic-file/basicServlet*.

```java
@Test
public void testDoGetValidCredentials() throws IOException {
  System.out.println("doGetValidCredentials");
  httpURLConnection.setRequestProperty(
    "Authorization", "Basic dGVzdFVzZXI6dGVzdFBhc3N3b3Jk"
  );

  String result = inputStreamToString(httpURLConnection.getInputStream());
  String expected = "Caller testUser in role USER";
  assertEquals(result, expected);
}

@Test
public void testDoGetInvalidPassword() throws IOException {
  System.out.println("doGetInvalidPassword");
  httpURLConnection.setRequestProperty(
    "Authorization", "Basic dGVzdFVzZXI6aW52YWxpZFBhc3N3b3Jk"
  );
  assertThrows(IOException.class, () -> {
    inputStreamToString(httpURLConnection.getInputStream());
  });
}

@Test
public void testDoGetNoCredentials() {
  System.out.println("doGetNoCredentials");
  assertThrows(IOException.class, () -> {
    inputStreamToString(httpURLConnection.getInputStream());
  });
}
```

## Further reading
- [JSR 375: Java EE Security API][jsr-375]
- [Java EE 8 by Arjan Tims][javaee8-zeef]
- [What's new in Java EE Security API 1.0?][whats-new-security-api]

[jsr-375]: https://www.jcp.org/en/jsr/detail?id=375
[jsr-375-ri]: https://github.com/javaee/security-soteria
[javaee8-zeef]: https://javaee8.zeef.com/arjan.tijms#block_40027
[guzman-github]: https://github.com/david-guzman/weblog-examples
[whats-new-security-api]: http://arjan-tijms.omnifaces.org/p/whats-new-in-java-ee-security-api-10.html
