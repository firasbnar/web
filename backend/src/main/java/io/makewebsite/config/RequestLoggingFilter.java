package io.makewebsite.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.util.Collections;
import java.util.stream.Collectors;

@Slf4j
@Component
public class RequestLoggingFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        ContentCachingRequestWrapper wrappedRequest = new ContentCachingRequestWrapper(request);
        ContentCachingResponseWrapper wrappedResponse = new ContentCachingResponseWrapper(response);

        long start = System.currentTimeMillis();
        filterChain.doFilter(wrappedRequest, wrappedResponse);
        long duration = System.currentTimeMillis() - start;

        if (response.getStatus() >= 400) {
            log.warn("=== REQUEST {} {} === Status: {}, Duration: {}ms, Params: {}",
                    request.getMethod(), request.getRequestURI(),
                    response.getStatus(), duration,
                    request.getParameterMap().entrySet().stream()
                            .map(e -> e.getKey() + "=" + String.join(",", e.getValue()))
                            .collect(Collectors.joining("&")));

            byte[] content = wrappedRequest.getContentAsByteArray();
            if (content.length > 0) {
                log.warn("Request body: {}", new String(content));
            }
        } else {
            log.debug("=== REQUEST {} {} === Status: {}, Duration: {}ms",
                    request.getMethod(), request.getRequestURI(), response.getStatus(), duration);
        }

        wrappedResponse.copyBodyToResponse();
    }
}