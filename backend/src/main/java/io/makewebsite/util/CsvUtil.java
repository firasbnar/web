package io.makewebsite.util;

import java.util.List;

public class CsvUtil {

    private static final String UTF_8_BOM = "\uFEFF";

    public static String escapeCsv(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    public static String buildCsv(String headerLine, List<String[]> rows) {
        StringBuilder sb = new StringBuilder(UTF_8_BOM);
        sb.append(headerLine).append("\n");
        for (String[] row : rows) {
            sb.append(String.join(",", row)).append("\n");
        }
        return sb.toString();
    }
}
