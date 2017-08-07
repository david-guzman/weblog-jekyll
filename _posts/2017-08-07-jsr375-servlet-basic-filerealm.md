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

## Servlet

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


## Further reading
- [JSR 375: Java EE Security API][jsr-375]
- [JASPIC by Arjan Tims][jaspic-zeef]
- [Adding Authentication Mechanisms to the GlassFish Servlet Container][techtips-auth]

[jsr-375]: https://www.jcp.org/en/jsr/detail?id=375
[jaspic-zeef]: https://jaspic.zeef.com/arjan.tijms
[guzman-github]: https://github.com/david-guzman/weblog-examples
[techtips-auth]: https://blogs.oracle.com/enterprisetechtips/entry/adding_authentication_mechanisms_to_the
