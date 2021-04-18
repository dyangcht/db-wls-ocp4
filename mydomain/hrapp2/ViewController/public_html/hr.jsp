<!DOCTYPE html>
<%@ page contentType="text/html;charset=UTF-8"%>
<%@ page import="java.sql.*"%>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <title>薪資參考對照表</title>
    <style>
        table, td, th {
          border: 2px solid black;
        }
        
        table {
          width: 80%;
          border-collapse: collapse;
        }
    </style>
   </head>
 <body>
<table border="1">
    <thead>
        <tr>
            <th colspan="3">參考資料</th>
        </tr>
    </thead>
    <tbody>
<%
Class.forName("oracle.jdbc.driver.OracleDriver").newInstance();
// String url="jdbc:oracle:thin:@a1b72c4e4851b4aec86b35bd34320c8d-1431416595.us-east-2.elb.amazonaws.com:1521:OraDoc";
String url="jdbc:oracle:thin:@database.database-namespace.svc.cluster.local:1521:OraDoc";
String user="c##hr";
String password="Welcome#1";

Connection conn= DriverManager.getConnection(url,user,password);
Statement stmt=conn.createStatement(ResultSet.TYPE_SCROLL_SENSITIVE,ResultSet.CONCUR_UPDATABLE);


String sql="select * from jobs";

ResultSet rs=stmt.executeQuery(sql);
%>
<tr><td>職位</td><td>最低薪資</td><td>最高薪資</td></tr>
<%
while(rs.next()) {%>
        <tr>
            <td><%=rs.getString(2)%> </td>
            <td><%=rs.getString(3)%> </td>
            <td><%=rs.getString(4)%> </td>
        </tr>
<%}%>
    </tbody>
</table>
<p></p>
<%out.print("資料庫操作成功，恭喜你");%>

<%
// connection closing
rs.close();
stmt.close();
conn.close();
%>
</body>
</html>