[![Build Maven](https://github.com/AndriyKalashnykov/tomcat-root-war/actions/workflows/build.yml/badge.svg)](https://github.com/AndriyKalashnykov/tomcat-root-war/actions/workflows/build.yml)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FAndriyKalashnykov%2Ftomcat-root-war&count_bg=%2333CD56&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# Java Web Application example

ROOT.war replaces Tomcat's default ROOT application - $TOMCAT_HOME/webapps/ROOT

## Pre-requisites

* [sdkman](https://sdkman.io/install)

    Install and use JDK 18

    ```bash
    sdk install java 18.0.2-tem
    sdk use java 18.0.2-tem
    ```
* [Apache Maven](https://maven.apache.org/install.html)

  Install Apache Maven 3.9.0

    ```bash
    sdk install maven 3.9.0
    sdk use maven 3.9.0
    ```
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Test with Jetty web server

```shell
git clone git@github.com:AndriyKalashnykov/tomcat-root-war.git
cd tomcat-root-war
mvn clean package jetty:run

xdg-open http://localhost:8080/index.html
```

Access http://localhost:8080/index.html or see [Tomcat ROOT WAR Web Application UI](https://github.com/AndriyKalashnykov/tomcat-root-war/blob/master/README.md#java-web-application-ui)

## Create WAR file

```shell
git clone git@github.com:AndriyKalashnykov/tomcat-root-war.git
cd tomcat-root-war
mvn clean install
```

## List content of generated WAR file

```shell
jar tf ./target/ROOT.war
```
## Replace TOMCAT ROOT application

Edit `$TOMCAT_HOME/conf/server.xml`: `autoDeploy` and `deployOnStartUp` needs to be set to `false`

```xml
<Host name="localhost"  appBase="webapps" unpackWARs="true" autoDeploy="false" deployOnStartUp="false">
```

Remove default ROOT folder and copy ROOT.war
```shell
rm -rf $TOMCAT_HOME/webapps/ROOT/
rm -f $TOMCAT_HOME/webapps/ROOT.war
cp ./target/ROOT.war $TOMCAT_HOME/webapps/ROOT.war
```

### Tomcat ROOT WAR Web Application UI

Default welcome page -  [http://localhost:8080/](http://localhost:8080/)
![index.html](images/http-8080-root.png)

JSP - [http://localhost:8080/index.jsp](http://localhost:8080/index.jsp)
![infoservlet](images/http-8080-index-jsp.png)

Servlet - [http://localhost:8080/infoservlet](http://localhost:8080/infoservlet)
![infoservlet](images/http-8080-infoservlet.png)

HTML - [http://localhost:8080/index.html](http://localhost:8080/index.html)
![infoservlet](images/http-8080-index-html.png)

## This project used in
* [Java Web Application (WAR) deployed as root "/" context onto Customized Bitnami Tomcat 9](https://github.com/AndriyKalashnykov/bitnami-tomcat9-jdk18-root-war)
* [Docker image of this application deployed onto Customized Bitnami Tomcat 9](https://hub.docker.com/r/andriykalashnykov/bitnami-tomcat9-jdk18-root-war)
