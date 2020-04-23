<%@page contentType="text/html" pageEncoding="UTF-8" %>
<%@ page import="java.net.InetAddress" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.util.Enumeration" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <link href="https://fonts.googleapis.com/css?family=Open+Sans" rel="stylesheet">
    <title>Java Web Application</title>
    <style>
        body {
            font-family: 'Open Sans', sans-serif;
        }

        table, td, tr {
            border: 1px solid;
            border-collapse: collapse;
        }

        span {
            font-weight: normal;
            font-size: 16px;
            color: black;
        }
    </style>
</head>
<body>

<%
    String hostName;
    String serverName;
    String ipAddr;
    Date Time;
    String Dtime;
    hostName = InetAddress.getLocalHost().getHostName();
    ipAddr = InetAddress.getLocalHost().getHostAddress();
    serverName = System.getProperty("java.vm.name");
    Time = new Date();
    Dtime = Time.toString();
%>

<h2> Server Info</h2>
<hr>

<div>
    <h4>Host Name : <span><%=  hostName %></span></h4>
    <h4>IP Address: <span><%=  ipAddr %></span></h4>
    <h4>JVM Name: <span><%=  serverName %></span></h4>
    <h4> Date & Time: <span> <%= Dtime %></h4>
</div>

<h4>HTTP Request URL : <span><%= request.getRequestURL() %></span></h4>
<h4>HTTP Request Method : <span><%= request.getMethod() %></span></h4>

<h4>HTTP Request Headers Received</h4>

<table>
    <%
        Enumeration enumeration = request.getHeaderNames();
        while (enumeration.hasMoreElements()) {
            String name = (String)
                    enumeration.nextElement();
            String value = request.getHeader(name);
    %>
    <tr>
        <td>
            <%=name %>
        </td>
        <td>
            <%=value %>
        </td>
    </tr>
    <% } %>
</table>

<h4>HTTP Cookies Received</h4>

<table>
    <%

        Cookie[] arr1 = request.getCookies();
        String cookiename = "";
        String cookievalue ="";
        if ((arr1 != null) && (arr1.length > 0))  {
        for (int i = 0; i < arr1.length; i++) {
            cookiename = arr1[i].getName();
            cookievalue = arr1[i].getValue();
        }

    %>
    <tr>
        <td>
            <%=cookiename %>
        </td>
        <td>
            <%=cookievalue %>
        </td>
    </tr>
    <% } %>
</table>


</body>
</html>
