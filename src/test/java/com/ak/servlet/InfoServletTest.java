package com.ak.servlet;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.io.PrintWriter;
import java.io.StringWriter;
import javax.servlet.RequestDispatcher;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;

class InfoServletTest {

    @Test
    void doGet_setsHtmlContentType_andForwardsToIndexJsp() throws Exception {
        HttpServletRequest request = mock(HttpServletRequest.class);
        HttpServletResponse response = mock(HttpServletResponse.class);
        RequestDispatcher dispatcher = mock(RequestDispatcher.class);
        when(response.getWriter()).thenReturn(new PrintWriter(new StringWriter()));
        when(request.getRequestDispatcher("index.jsp")).thenReturn(dispatcher);

        new InfoServlet().doGet(request, response);

        verify(response).setContentType("text/html;charset=UTF-8");
        verify(request).getRequestDispatcher("index.jsp");
        verify(dispatcher).forward(request, response);
    }

    @Test
    void doPost_forwardsToIndexJsp() throws Exception {
        HttpServletRequest request = mock(HttpServletRequest.class);
        HttpServletResponse response = mock(HttpServletResponse.class);
        RequestDispatcher dispatcher = mock(RequestDispatcher.class);
        when(response.getWriter()).thenReturn(new PrintWriter(new StringWriter()));
        when(request.getRequestDispatcher("index.jsp")).thenReturn(dispatcher);

        new InfoServlet().doPost(request, response);

        verify(dispatcher).forward(request, response);
    }
}
