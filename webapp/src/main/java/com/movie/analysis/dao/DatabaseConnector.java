package com.movie.analysis.dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * MySQL 数据库连接器 — 线程安全的轻量级 JDBC 封装
 * =================================================================
 * 设计原则:
 *   1. 每次调用 getConnection() 创建新连接，避免多线程共享单例连接导致并发崩溃
 *   2. queryToJson() 方法自动关闭连接（finally 块），防止连接泄漏
 *   3. 连接 URL 指向 VMware NAT 虚拟机 (192.168.11.130:3306)
 *
 * 数据源:
 *   - 默认 MovieLens 1M 数据 → 无表前缀 (dashboard_summary, rating_distribution ...)
 *   - 自定义数据集 → ds{N}_ 表前缀 (ds3_dashboard_summary ...)
 *
 * 并发安全:
 *   修复前: static Connection 单例 → 8 个并发 AJAX 请求互相覆盖 → 全部返回 error
 *   修复后: 每次新建连接+用完即关 → 各请求独立，互不干扰
 * =================================================================
 */
public class DatabaseConnector {

    private static final String URL      = "jdbc:mysql://192.168.11.130:3306/movie_analysis?useSSL=false&amp;useUnicode=true&amp;characterEncoding=utf8mb4&amp;serverTimezone=Asia/Shanghai";
    private static final String USER     = "movieapp";
    private static final String PASSWORD = "movieapp123";

    static {
        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

    // Each call creates a new connection — safe for concurrent requests
    public static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(URL, USER, PASSWORD);
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

    /**
     * 执行查询并返回 JSON 格式结果
     */
    public static String queryToJson(String sql, String[] columns) {
        StringBuilder json = new StringBuilder("[");
        Connection c = null;
        try {
            c = getConnection();
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
        } finally {
            try { if (c != null) c.close(); } catch (SQLException ignored) {}
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
