package io.makewebsite.util;

import jakarta.servlet.http.HttpServletRequest;

public class NetworkUtils {

    private static final String[] IP_HEADERS = {
        "X-Forwarded-For",
        "X-Real-IP",
        "CF-Connecting-IP",
        "True-Client-IP"
    };

    public static String resolveClientIp(HttpServletRequest request) {
        for (String header : IP_HEADERS) {
            String value = request.getHeader(header);
            if (value != null && !value.isBlank() && !"unknown".equalsIgnoreCase(value)) {
                String ip = value.split(",")[0].trim();
                if (!ip.isEmpty()) {
                    return ip;
                }
            }
        }
        String remoteAddr = request.getRemoteAddr();
        if (remoteAddr != null) {
            return remoteAddr;
        }
        return "0.0.0.0";
    }

    public static boolean isPrivateIp(String ip) {
        if (ip == null) return false;
        if (ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("127.")
                || "::1".equals(ip) || "0:0:0:0:0:0:0:1".equals(ip)
                || "localhost".equalsIgnoreCase(ip)) {
            return true;
        }
        if (ip.startsWith("172.") && ip.length() > 5) {
            try {
                int dot = ip.indexOf('.', 4);
                if (dot > 0) {
                    int second = Integer.parseInt(ip.substring(4, dot));
                    return second >= 16 && second <= 31;
                }
            } catch (Exception e) {
                return false;
            }
        }
        // Catch any other IPv6 loopback forms (e.g. 0000:...:0001)
        if (ip.contains(":") && ip.endsWith(":1") && ip.startsWith("0")) {
            return true;
        }
        return false;
    }
}
