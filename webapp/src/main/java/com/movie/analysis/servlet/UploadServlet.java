package com.movie.analysis.servlet;

import com.movie.analysis.dao.CsvImporter;
import com.movie.analysis.dao.DatabaseConnector;
import com.google.gson.Gson;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.Part;
import java.io.*;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.*;

/**
 * 数据集上传 Servlet — 支持自定义电影数据集
 * =================================================================
 * 流程:
 *   1. 接收 multipart 上传的 CSV 文件
 *   2. 本地保存 + 调用 CsvImporter 做快速 SQL 分析（立即反馈）
 *   3. SCP 文件到虚拟机 ~/movie_bigdata_analysis/data/custom/
 *   4. SSH 触发 Spark 分析 (spark_custom_analysis.py) → MySQL
 *   5. 返回统计摘要
 * =================================================================
 */
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,      // 1 MB 内存缓冲
    maxFileSize = 50 * 1024 * 1024,       // 单文件最大 50 MB
    maxRequestSize = 150 * 1024 * 1024    // 请求最大 150 MB
)
public class UploadServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        req.setCharacterEncoding("UTF-8");
        resp.setCharacterEncoding("UTF-8");
        resp.setContentType("application/json;charset=UTF-8");

        Map<String, Object> result = new LinkedHashMap<>();
        Gson gson = new Gson();

        try {
            // 1. 获取数据集名称
            String datasetName = req.getParameter("datasetName");
            if (datasetName == null || datasetName.trim().isEmpty()) {
                datasetName = "Dataset_" + System.currentTimeMillis() % 100000;
            }

            // 2. 获取上传的文件
            Collection<Part> parts = req.getParts();
            List<File> uploadedFiles = new ArrayList<>();

            for (Part part : parts) {
                String fileName = extractFileName(part);
                if (fileName == null || fileName.isEmpty()) continue;
                if (!fileName.matches(".*\\.(csv|dat|txt)$")) continue;

                File tempFile = File.createTempFile("upload_", "_" + fileName);
                try (InputStream in = part.getInputStream();
                     FileOutputStream out = new FileOutputStream(tempFile)) {
                    byte[] buf = new byte[8192];
                    int len;
                    while ((len = in.read(buf)) != -1) out.write(buf, 0, len);
                }
                uploadedFiles.add(tempFile);
            }

            if (uploadedFiles.isEmpty()) {
                result.put("success", false);
                result.put("message", "未找到有效的 CSV 文件，请上传 .csv / .dat / .txt 格式文件");
                resp.getWriter().write(gson.toJson(result));
                return;
            }

            // 3. 创建数据集记录，获取 ID
            int dsId = registerDataset(datasetName);

            // 4. 本地快速分析（SQL方式）
            CsvImporter importer = new CsvImporter();
            importer.setDsId(dsId);
            Map<String, Integer> counts = importer.importFiles(uploadedFiles);

            int movies = counts.getOrDefault("movies", 0);
            int ratings = counts.getOrDefault("ratings", 0);
            int users = counts.getOrDefault("users", 0);
            int total = movies + ratings + users;

            // If no data was imported at all, skip Spark and return error
            if (total == 0) {
                // Clean up temp files and dataset record
                for (File f : uploadedFiles) f.delete();
                deleteDatasetQuietly(dsId);
                result.put("success", false);
                result.put("message", "❌ 数据导入失败：文件中未检测到有效的 CSV 数据。请确认：\n" +
                    "1. 文件不是空文件\n" +
                    "2. 第一行为列名（如 user_id,movie_id,rating）\n" +
                    "3. 数据列之间用逗号、Tab 或 :: 分隔");
                resp.getWriter().write(gson.toJson(result));
                return;
            }

            // 5. SCP + Spark 后台分析（仅在SQL导入成功时触发）
            triggerSparkAnalysis(dsId, uploadedFiles);

            // 6. 更新数据集统计
            updateDatasetStats(dsId);

            result.put("success", true);
            result.put("datasetId", dsId);
            result.put("message", String.format(
                "数据集 [%s] (ID=%d) — SQL 导入: %d 电影, %d 评分, %d 用户",
                datasetName, dsId, movies, ratings, users));
            result.put("stats", null);  // stats now in per-dataset tables

        } catch (Exception e) {
            result.put("success", false);
            result.put("message", "处理失败: " + e.getMessage());
            e.printStackTrace();
        }

        resp.getWriter().write(gson.toJson(result));
    }

    /** 从 multipart header 提取文件名 */
    private String extractFileName(Part part) {
        String header = part.getHeader("content-disposition");
        if (header == null) return null;
        for (String token : header.split(";")) {
            token = token.trim();
            if (token.startsWith("filename=")) {
                return token.substring(10).replace("\"", "");
            }
        }
        return null;
    }

    /** Register dataset and return ID */
    private int registerDataset(String name) throws Exception {
        Connection conn = DatabaseConnector.getConnection();
        java.sql.PreparedStatement ps = conn.prepareStatement(
            "INSERT INTO datasets (name) VALUES (?)",
            java.sql.Statement.RETURN_GENERATED_KEYS);
        ps.setString(1, name);
        ps.executeUpdate();
        java.sql.ResultSet rs = ps.getGeneratedKeys();
        if (rs.next()) return rs.getInt(1);
        return 1;
    }

    /** Update dataset row counts from dashboard_summary (Spark) or ratings_custom (CsvImporter fallback) */
    private void updateDatasetStats(int dsId) throws Exception {
        Connection conn = DatabaseConnector.getConnection();
        java.sql.Statement stmt = conn.createStatement();
        String p = "ds" + dsId + "_";
        try {
            // Prefer Spark's dashboard_summary
            java.sql.ResultSet rs = stmt.executeQuery(
                "SELECT total_movies, total_ratings, total_users FROM " + p + "dashboard_summary LIMIT 1");
            if (rs.next() && rs.getLong(2) > 0) {
                java.sql.PreparedStatement ps = conn.prepareStatement(
                    "UPDATE datasets SET movie_count=?, rating_count=?, user_count=? WHERE id=?");
                ps.setLong(1, rs.getLong(1));
                ps.setLong(2, rs.getLong(2));
                ps.setLong(3, rs.getLong(3));
                ps.setInt(4, dsId);
                ps.executeUpdate();
                return;
            }
        } catch (Exception ignored) {}
        try {
            // Fallback: CsvImporter tables
            java.sql.ResultSet rs = stmt.executeQuery(
                "SELECT (SELECT COUNT(DISTINCT movie_id) FROM " + p + "ratings_custom)," +
                "(SELECT COUNT(*) FROM " + p + "ratings_custom)," +
                "(SELECT COUNT(DISTINCT user_id) FROM " + p + "ratings_custom)");
            if (rs.next() && rs.getLong(2) > 0) {
                java.sql.PreparedStatement ps = conn.prepareStatement(
                    "UPDATE datasets SET movie_count=?, rating_count=?, user_count=? WHERE id=?");
                ps.setLong(1, rs.getLong(1));
                ps.setLong(2, rs.getLong(2));
                ps.setLong(3, rs.getLong(3));
                ps.setInt(4, dsId);
                ps.executeUpdate();
            }
        } catch (Exception ignored) {}
    }

    /** Clean up failed dataset registration */
    private void deleteDatasetQuietly(int dsId) {
        try {
            Connection conn = DatabaseConnector.getConnection();
            java.sql.Statement stmt = conn.createStatement();
            stmt.executeUpdate("DELETE FROM datasets WHERE id=" + dsId);
            stmt.close();
            conn.close();
        } catch (Exception ignored) {}
    }

    /** SCP + Spark, with dataset ID for custom table prefixes */
    private String triggerSparkAnalysis(int dsId, List<File> files) {
        new Thread(() -> {
            try {
                // Per-dataset subdirectory to isolate data
                String dsDir = "~/movie_bigdata_analysis/data/custom/ds" + dsId;
                execNoWait("ssh", "my-hadoop", "rm -rf " + dsDir + " && mkdir -p " + dsDir);
                for (File f : files) {
                    execNoWait("scp", f.getAbsolutePath(), "my-hadoop:" + dsDir + "/");
                }
                // Clean up temp files AFTER SCP completes
                for (File f : files) f.delete();

                execNoWait("ssh", "my-hadoop",
                    "nohup /usr/local/spark/bin/spark-submit" +
                    " --jars /usr/local/spark/jars/mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" +
                    " ~/movie_bigdata_analysis/scripts/spark_custom_analysis.py " + dsId +
                    " > /tmp/spark_custom_" + dsId + ".log 2>&1 &");
            } catch (Exception e) {
                System.err.println("[Spark] " + e.getMessage());
            }
        }).start();
        return "Spark analyzing...";
    }

    /** 使用ProcessBuilder执行命令，避免Windows cmd.exe的引号问题 */
    private void execNoWait(String... cmd) throws Exception {
        Process p = new ProcessBuilder(cmd).redirectErrorStream(false).start();
        new Thread(() -> { try {
            byte[] buf = new byte[4096]; int n;
            while ((n = p.getInputStream().read(buf)) != -1) {}
        } catch (Exception ignored) {} }).start();
        new Thread(() -> { try {
            byte[] buf = new byte[4096]; int n;
            while ((n = p.getErrorStream().read(buf)) != -1) {}
        } catch (Exception ignored) {} }).start();
        p.waitFor();
    }
}
