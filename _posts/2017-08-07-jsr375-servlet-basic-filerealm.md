---
layout: post
title: "JSR 375 BASIC authentication with a Servlet (file realm)"
date: 2017-08-07
tags:
- JSR 375
- Servlet
- BASIC authentication
---

## Background

## Source code
The complete source code of the example used in this post is available on the
weblog's [Github repo][guzman-github], in the `servlet-jsr375` folder.

The integration tests are run on a local installation of Glassfish 4.1.1 (web
profile) and do not use Arquillian or Cargo. The configuration of Glassfish is
done by Maven.

Java 8 and Apache Maven 3 are required to run the sample application.

## Java EE Security RI - Soteria

The version of Soteria used in this example is 1.0-b11-SNAPSHOT

```xml
<dependency>
  <groupId>org.glassfish.soteria</groupId>
  <artifactId>javax.security.enterprise</artifactId>
  <version>${dep.soteria.version}</version>
</dependency>
```

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

## Servlet

### @BasicAuthenticationMechanismDefinition annotation

```java
@WebServlet(urlPatterns = "/basicServlet")
@DeclareRoles({"USER"})
@BasicAuthenticationMechanismDefinition(realmName = "file")
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

## Testing

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
[javaee8-zeef]: https://javaee8.zeef.com/arjan.tijms#block_40027
[guzman-github]: https://github.com/david-guzman/weblog-examples
[whats-new-security-api]: http://arjan-tijms.omnifaces.org/p/whats-new-in-java-ee-security-api-10.html
