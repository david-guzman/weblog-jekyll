---
layout: post
title: "Testing JSR 375 BASIC authentication in a Servlet (LDAP identity store)"
date: 2017-08-14
tags:
- JSR 375
- Servlet
- BASIC authentication
- LDAP
---

As a continuation to
the [example in the previous post][post-jsr375-file] on JSR 375, this post
covers the configuration of an LDAP identity store from the Java EE Security API
to validate the caller's credentials.

## Source code

The complete source code of the example used in this post is available on the
weblog's [Github repo][guzman-github], in the
`servlet-jsr375/servlet-basic-ldap` folder.

Unlike the previous example, where the sample application is deployed on
Glassfish to make use of its *file realm* for the validation of the caller's
credentials, the web application in this example is deployed on a local instance
of Payara 4.1.2.172 (web profile).

Java 8 and Apache Maven 3 are required to run the sample application.

## Identity store

Equivalent to the concept of *realm* in Glassfish, the Java EE Security API
introduces the `IdentityStore` interface to offer an abstract representation of
a database of valid users (*callers*) and groups.

The specification defines `IdentityStore` as:

> IdentityStore provides an abstraction of an identity store, which is a
database or directory (store) of identity information about a population of
users that includes an application’s callers. An identity store holds caller
names, group membership information, and information sufficient to allow it to
validate a caller’s credentials.

There are two built-in `IdentityStore` CDI beans that must be supported by Java
EE containers implementing the API: LDAP and database. The former is the one
used in the sample web application.

## @LdapIdentityStoreDefinition

The LDAP identity store is configured with the `@LdapIdentityStoreDefinition`
annotation. As in the previous example, there is no configuration taking place
in `web.xml`.

The example in this post uses a very simple directory
(`src/test/resources/test.ldif`), with users and their credentials as members of
`caller` organisational unit and groups under `ou=group,dc=guzman,dc=me,dc=uk`:

```
dn: ou=caller,dc=guzman,dc=me,dc=uk
objectclass: top
objectclass: organizationalUnit
ou: caller

dn: uid=testUser,ou=caller,dc=guzman,dc=me,dc=uk
objectclass: top
objectclass: uidObject
objectclass: person
uid: testUser
cn: Test User
sn: Test
userPassword: testPassword

dn: ou=group,dc=guzman,dc=me,dc=uk
objectclass: top
objectclass: organizationalUnit
ou: group

dn: cn=USER,ou=group,dc=guzman,dc=me,dc=uk
objectclass: top
objectclass: groupOfNames
cn: USER
member: uid=testUser,ou=caller,dc=guzman,dc=me,dc=uk
```

There are 24 methods in `@LdapIdentityStoreDefinition` (further information
about these methods in its [javadoc][ldapidentitystoredef-javadoc]) but for the
directory used in this example only `url()`,`callerBaseDn()` and
`groupSearchBase()` are needed:

```java
@WebServlet(urlPatterns = "/ldapServlet")
@DeclareRoles({"USER"})
@BasicAuthenticationMechanismDefinition(realmName = "www-authenticate-realm")
@LdapIdentityStoreDefinition(
  url = "ldap://localhost:10389/",
  callerBaseDn = "ou=caller,dc=guzman,dc=me,dc=uk",
  groupSearchBase = "ou=group,dc=guzman,dc=me,dc=uk"
)
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

Both authentication mechanism and identity store are configured with annotations
in a few lines of code. The descriptor `glassfish-web.xml` is only required for
mapping groups to security roles:

```xml
<security-role-mapping>
  <role-name>USER</role-name>
  <group-name>USER</group-name>
</security-role-mapping>
```

## Testing

UnboundID SDK offers an in-memory LDAP server that can be used for testing. In
this example, `ldap-maven-plugin` takes care of starting the server and seeding
the directory with the data provided in `src/test/resources/test.ldif`.

```xml
<plugin>
  <groupId>com.btmatthews.maven.plugins</groupId>
  <artifactId>ldap-maven-plugin</artifactId>
  <version>${plu.ldap.version}</version>
  <configuration>
    <monitorKey>ldap</monitorKey>
    <monitorPort>11389</monitorPort>
  </configuration>
  <executions>
    <execution>
      <id>start-ldap</id>
      <goals>
        <goal>run</goal>
      </goals>
      <configuration>
        <daemon>true</daemon>
        <ldapPort>10389</ldapPort>
        <monitorKey>ldap</monitorKey>
        <monitorPort>11389</monitorPort>
        <rootDn>dc=guzman,dc=me,dc=uk</rootDn>
        <serverType>unboundid</serverType>
        <ldifFile>${project.basedir}/src/test/resources/test.ldif</ldifFile>
      </configuration>
      <phase>pre-integration-test</phase>
    </execution>
    <execution>
      <id>stop-ldap</id>
      <goals>
        <goal>stop</goal>
      </goals>
      <phase>post-integration-test</phase>
    </execution>
  </executions>
</plugin>
```

As in the previous post, the tests use an instance of `HttpURLConnection` to
call the servlet (`LdapServlet`) on
*http://localhost:8080/servlet-basic-ldap/ldapServlet*.

## Issues

The example does not work on Glassfish 4.1, calling the servlet generates a HTTP
500 response code.

## Further reading
- [JSR 375: Java EE Security API][jsr-375]
- [Java EE 8 by Arjan Tims][javaee8-zeef]
- [What's new in Java EE Security API 1.0?][whats-new-security-api]

[jsr-375]: https://www.jcp.org/en/jsr/detail?id=375
[jsr-375-ri]: https://github.com/javaee/security-soteria
[javaee8-zeef]: https://javaee8.zeef.com/arjan.tijms#block_40027
[guzman-github]: https://github.com/david-guzman/weblog-examples
[post-jsr375-file]:  {{ site.baseurl }}{% post_url 2017-08-07-jsr375-servlet-basic-filerealm %}
[whats-new-security-api]: http://arjan-tijms.omnifaces.org/p/whats-new-in-java-ee-security-api-10.html
[ldapidentitystoredef-javadoc]: https://javaee.github.io/security-api/apidocs/javax/security/enterprise/identitystore/LdapIdentityStoreDefinition.html
