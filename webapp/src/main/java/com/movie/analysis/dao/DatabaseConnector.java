package com.movie.analysis.dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * MySQL 数据库连接器
 * 负责成员: E (数据可视化)
 * 从 MySQL movie_analysis 数据库读取 Hive 分析结果
 */
public class DatabaseConnector {

    private static final String URL      = "jdbc:mysql://172.27.17.128:3306/movie_analysis?useSSL=false&amp;useUnicode=true&amp;characterEncoding=utf8mb4&amp;serverTimezone=Asia/Shanghai";
    private static final String USER     = "movieapp";
    private static final String PASSWORD = "movieapp123";

    private static Connection conn = null;

    static {
        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

    public static Connection getConnection() throws SQLException {
        if (conn == null || conn.isClosed()) {
            conn = DriverManager.getConnection(URL, USER, PASSWORD);
        }
        return conn;
    }

    /** Check if user has uploaded custom data */
    public static boolean hasCustomData() {
        try {
            Connection c = getConnection();
            Statement stmt = c.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM ratings_custom");
            if (rs.next()) return rs.getInt(1) > 0;
        } catch (SQLException ignored) {}
        return false;
    }

    /**
     * Get table name: prefer custom table if data exists
     * e.g. "ratings" → "ratings_custom" (when custom data uploaded)
     *      "movies"  → "movies_custom"
     */
    public static String tableName(String baseName) {
        try {
            Connection c = getConnection();
            Statement stmt = c.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM ratings_custom");
            if (rs.next() && rs.getInt(1) > 0) {
                return baseName + "_custom";
            }
        } catch (SQLException ignored) {}
        return baseName;
    }

    public static void closeConnection() {
        try {
            if (conn != null && !conn.isClosed()) {
                conn.close();
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    /**
     * 执行查询并返回 JSON 格式结果
     */
    public static String queryToJson(String sql, String[] columns) {
        StringBuilder json = new StringBuilder("[");
        try {
            Connection c = getConnection();
            Statement stmt = c.createStatement();
            ResultSet rs = stmt.executeQuery(sql);

            boolean firstRow = true;
            while (rs.next()) {
                if (!firstRow) json.append(",");
                json.append("{");
                for (int i = 0; i < columns.length; i++) {
                    if (i > 0) json.append(",");
                    json.append("\"").append(columns[i]).append("\":");
                    String val = rs.getString(i + 1);
                    if (val == null) {
                        json.append("null");
                    } else if (isNumeric(val)) {
                        json.append(val);
                    } else {
                        json.append("\"").append(escapeJson(val)).append("\"");
                    }
                }
                json.append("}");
                firstRow = false;
            }
            rs.close();
            stmt.close();
        } catch (SQLException e) {
            return "{\"error\":\"" + escapeJson(e.getMessage()) + "\"}";
        }
        json.append("]");
        return json.toString();
    }

    private static boolean isNumeric(String s) {
        return s.matches("-?\\d+(\\.\\d+)?");
    }

    private static String escapeJson(String s) {
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r");
    }
}
