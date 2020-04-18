[![Build Status](https://travis-ci.org/AndriyKalashnykov/tomcat-root-war.svg?branch=master)](https://travis-ci.org/AndriyKalashnykov/tomcat-root-war)

# Java Web Application example

ROOT.war replaces Tomcat's default ROOT application - $TOMCAT_HOME/webapps/ROOT

### Test with Jetty web server

```shell
git clone git@github.com:AndriyKalashnykov/tomcat-root-war.git
cd tomcat-root-war
mvn jetty:run

open http://localhost:8080
```

Access http://localhost:8080

### Create WAR file

```shell
git clone git@github.com:AndriyKalashnykov/tomcat-root-war.git
cd tomcat-root-war
mvn clean install
```

### List content of generated WAR file

```shell
jar tf ./target/ROOT.war
```
### Replace TOMCAT ROOT application

```shell
rm -rf $TOMCAT_HOME/webapps/ROOT
rm -f $TOMCAT_HOME/webapps/ROOT.war
cp ./target/ROOT.war $TOMCAT_HOME/webapps/ROOT.war
```

## Links

[How to change Tomcat ROOT application?](https://stackoverflow.com/questions/715506/how-to-change-the-root-application)