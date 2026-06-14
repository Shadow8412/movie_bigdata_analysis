package com.movie.analysis.dao;

import java.io.*;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.*;

/**
 * CSV 导入器 — 自动识别电影数据集格式
 * =================================================================
 * 功能:
 *   1. 自动检测分隔符 (, :: \t)
 *   2. 自动识别列名 (movie_id/rating/user_id 等)
 *   3. 按类目 (movies/ratings/users) 分表导入 MySQL
 *   4. 支持 MovieLens 格式 (::) 和通用 CSV (,) 格式
 * =================================================================
 */
public class CsvImporter {

    // 已知列名映射（支持多种变体）
    private static final Set<String> MOVIE_COLS = new HashSet<>(Arrays.asList(
        "movie_id", "movieid", "movie_id", "movie"));
    private static final Set<String> RATING_COLS = new HashSet<>(Arrays.asList(
        "rating", "score", "rate"));
    private static final Set<String> USER_COLS = new HashSet<>(Arrays.asList(
        "user_id", "userid", "user_id"));
    private static final Set<String> GENRE_COLS = new HashSet<>(Arrays.asList(
        "genre", "genres", "category", "categories"));

    private int dsId = 0;           // 0=default tables, >0=ds{N}_ tables
    private String prefix = "";

    /** Set dataset ID for creating per-dataset tables (ds{N}_) */
    public void setDsId(int id) { this.dsId = id; this.prefix = "ds" + id + "_"; }

    /** 入口：处理多个文件，返回各表导入行数 */
    public Map<String, Integer> importFiles(List<File> files) throws Exception {
        Map<String, Integer> result = new LinkedHashMap<>();
        result.put("movies", 0);
        result.put("ratings", 0);
        result.put("users", 0);
        int totalSkipped = 0;

        // 确保表结构存在
        ensureTablesExist();

        for (File file : files) {
            if (file.length() == 0) {
                System.err.println("[CsvImporter] Warning: skipping empty file: " + file.getName());
                continue;
            }
            List<Map<String, String>> rows = parseFile(file);
            if (rows.isEmpty()) {
                System.err.println("[CsvImporter] Warning: no valid data in: " + file.getName());
                continue;
            }

            String tableType = detectTableType(rows.get(0).keySet());
            int[] counts = insertRows(tableType, rows);
            result.put(tableType, result.get(tableType) + counts[0]);
            totalSkipped += counts[1];
        }
        if (totalSkipped > 0) {
            System.err.println("[CsvImporter] Total skipped rows: " + totalSkipped);
        }
        return result;
    }

    /** 解析单个 CSV 文件，返回 <列名→值> 的映射列表 */
    private List<Map<String, String>> parseFile(File file) throws IOException {
        List<Map<String, String>> rows = new ArrayList<>();
        List<String> lines = new ArrayList<>();

        // 读取全部行
        try (BufferedReader br = new BufferedReader(new InputStreamReader(
                new FileInputStream(file), detectCharset(file)))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (!line.isEmpty()) lines.add(line);
            }
        }

        if (lines.isEmpty()) return rows;

        // 预检：第一行必须包含可识别的列名或分隔符
        String firstLine = lines.get(0);
        String sep = detectSeparator(firstLine);

        // If no recognizable separator (comma, tab, ::) and no known header words, reject
        if (!firstLine.contains(",") && !firstLine.contains("\t") && !firstLine.contains("::")) {
            System.err.println("[CsvImporter] Rejected: no valid delimiter in file: " + file.getName());
            return rows;
        }

        // If first line has none of the typical column names, it's probably not a CSV header
        if (!looksLikeDataFile(firstLine, sep)) {
            System.err.println("[CsvImporter] Rejected: no recognizable columns in: " + file.getName());
            return rows;
        }

        // 解析表头
        String[] headers = firstLine.split(sep, -1);
        boolean hasHeader = isHeaderRow(headers);
        int dataStart = hasHeader ? 1 : 0;

        // 清理表头
        List<String> cleanHeaders = new ArrayList<>();
        if (hasHeader) {
            for (String h : headers) cleanHeaders.add(normalizeCol(h));
        } else {
            // 无表头时用 _c0,_c1...
            for (int i = 0; i < headers.length; i++) cleanHeaders.add("_c" + i);
        }

        // 解析数据行，跳过重复表头
        for (int i = dataStart; i < lines.size(); i++) {
            String[] fields = lines.get(i).split(sep, -1);
            if (fields.length < 2) continue;
            // Skip rows that look like repeated headers
            if (hasHeader && isHeaderRow(fields)) {
                System.err.println("[CsvImporter] Skipping repeated header at line " + (i+1));
                continue;
            }

            Map<String, String> row = new LinkedHashMap<>();
            for (int j = 0; j < Math.min(fields.length, cleanHeaders.size()); j++) {
                row.put(cleanHeaders.get(j), fields[j].trim());
            }
            rows.add(row);
        }

        return rows;
    }

    /** Check if first line looks like a valid data file header */
    private boolean looksLikeDataFile(String line, String sep) {
        String[] fields = line.split(sep, -1);
        if (fields.length < 2) return false;
        // Must have at least one recognizable column name or numeric-looking ID column
        for (String f : fields) {
            f = f.trim().toLowerCase().replaceAll("[\"'`]", "");
            if (f.equals("user_id") || f.equals("userid") || f.equals("user") ||
                f.equals("movie_id") || f.equals("movieid") || f.equals("movie") ||
                f.equals("rating") || f.equals("score") || f.equals("rate") ||
                f.equals("title") || f.equals("genres") || f.equals("genre") ||
                f.equals("gender") || f.equals("age") || f.equals("occupation") ||
                f.matches(".*(id|rating|score|title|genre|user|movie).*")) {
                return true;
            }
        }
        // Also accept if first data row (line 2) looks numeric (headerless CSV)
        return false;
    }

    /** 检测分隔符 */
    private String detectSeparator(String line) {
        if (line.contains("::")) return "::";
        if (line.contains("\t")) return "\t";
        return ",";
    }

    /** 检测文件编码 */
    private String detectCharset(File file) {
        // 简单检测：优先 UTF-8，回退 GBK
        try (InputStream is = new FileInputStream(file)) {
            byte[] bom = new byte[3];
            int n = is.read(bom);
            if (n >= 3 && bom[0] == (byte)0xEF && bom[1] == (byte)0xBB && bom[2] == (byte)0xBF)
                return "UTF-8";
        } catch (Exception ignored) {}
        return "UTF-8";
    }

    /** 判断第一行是否为表头（包含常见列名） */
    private boolean isHeaderRow(String[] fields) {
        for (String f : fields) {
            f = f.trim().toLowerCase();
            if (f.equals("movie_id") || f.equals("movieid") || f.equals("user_id") ||
                f.equals("userid") || f.equals("rating") || f.equals("title") ||
                f.equals("movie") || f.equals("score")) return true;
        }
        return false;
    }

    /** 标准化列名（去引号/空格/统一小写） */
    private String normalizeCol(String col) {
        col = col.replaceAll("[\"'`]", "").trim().toLowerCase();
        // 映射常见别名
        if (col.equals("movieid")) return "movie_id";
        if (col.equals("userid")) return "user_id";
        if (col.equals("score") || col.equals("rate")) return "rating";
        return col;
    }

    /** 根据列名判断表类型 */
    private String detectTableType(Set<String> columns) {
        int movieScore = 0, ratingScore = 0, userScore = 0;

        for (String col : columns) {
            if (MOVIE_COLS.contains(col) || col.equals("title")) movieScore++;
            if (RATING_COLS.contains(col)) ratingScore++;
            if (USER_COLS.contains(col)) userScore++;
        }

        if (ratingScore > 0 && movieScore > 0) return "ratings";
        if (ratingScore > 0) return "ratings";
        if (movieScore >= 2 || (movieScore >= 1 && columns.contains("title"))) return "movies";
        if (userScore >= 1) return "users";
        return "ratings"; // 默认当作评分文件
    }

    /** 创建存储表 (如果不存在) — 使用 ds{N}_ 前缀 */
    private void ensureTablesExist() throws Exception {
        Connection conn = DatabaseConnector.getConnection();
        java.sql.Statement stmt = conn.createStatement();
        String p = prefix;  // e.g., "ds1_" or ""

        stmt.execute(
            "CREATE TABLE IF NOT EXISTS " + p + "movies_custom (" +
            "  movie_id INT, title VARCHAR(500), title_full VARCHAR(500)," +
            "  genres_raw VARCHAR(500)" +
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        stmt.execute(
            "CREATE TABLE IF NOT EXISTS " + p + "ratings_custom (" +
            "  user_id INT, movie_id INT, rating DOUBLE, ts BIGINT" +
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        stmt.execute(
            "CREATE TABLE IF NOT EXISTS " + p + "users_custom (" +
            "  user_id INT, gender VARCHAR(10), age INT, age_group VARCHAR(20)," +
            "  occupation_id INT, occupation VARCHAR(50), zipcode VARCHAR(20)" +
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        // Also create standard result tables
        String[] stdTables = {"rating_distribution","top_movies","genre_stats",
            "active_users","gender_comparison","age_group_stats","occupation_stats","dashboard_summary"};
        for (String t : stdTables) {
            stmt.execute("CREATE TABLE IF NOT EXISTS " + p + t + " LIKE " + t);
        }
    }

    /** 批量插入数据，返回 [成功数, 跳过数] */
    private int[] insertRows(String tableType, List<Map<String, String>> rows) throws Exception {
        if (rows.isEmpty()) return new int[]{0, 0};

        Connection conn = DatabaseConnector.getConnection();
        conn.setAutoCommit(false);

        String table = prefix + tableType + "_custom";
        int count = 0, skipped = 0;

        switch (tableType) {
            case "movies":
                PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO " + table + " (movie_id, title, title_full, genres_raw) VALUES (?,?,?,?)");
                for (Map<String, String> row : rows) {
                    try {
                        ps.setInt(1, parseInt(row.get("movie_id")));
                        ps.setString(2, row.getOrDefault("title", ""));
                        ps.setString(3, row.getOrDefault("title_full", row.getOrDefault("title", "")));
                        ps.setString(4, row.getOrDefault("genres_raw", row.getOrDefault("genres", "")));
                        ps.addBatch(); count++;
                    } catch (Exception ignored) { skipped++; }
                    if (count % 1000 == 0) ps.executeBatch();
                }
                ps.executeBatch();
                break;

            case "ratings":
                ps = conn.prepareStatement(
                    "INSERT INTO " + table + " (user_id, movie_id, rating, ts) VALUES (?,?,?,?)");
                for (Map<String, String> row : rows) {
                    try {
                        double rating = parseDouble(row.get("rating"));
                        // Skip obviously invalid ratings (negative or >10)
                        if (rating < 0 || rating > 10) { skipped++; continue; }
                        ps.setInt(1, parseInt(row.get("user_id")));
                        ps.setInt(2, parseInt(row.get("movie_id")));
                        ps.setDouble(3, rating);
                        ps.setLong(4, parseLong(row.getOrDefault("timestamp",
                            row.getOrDefault("ts", "0"))));
                        ps.addBatch(); count++;
                    } catch (Exception ignored) { skipped++; }
                    if (count % 1000 == 0) ps.executeBatch();
                }
                ps.executeBatch();
                break;

            case "users":
                ps = conn.prepareStatement(
                    "INSERT INTO " + table + " (user_id, gender, age, age_group, occupation_id, occupation, zipcode) VALUES (?,?,?,?,?,?,?)");
                for (Map<String, String> row : rows) {
                    try {
                        ps.setInt(1, parseInt(row.get("user_id")));
                        ps.setString(2, row.getOrDefault("gender", ""));
                        ps.setInt(3, parseInt(row.get("age")));
                        ps.setString(4, row.getOrDefault("age_group", ""));
                        ps.setInt(5, parseInt(row.getOrDefault("occupation_id", "0")));
                        ps.setString(6, row.getOrDefault("occupation", ""));
                        ps.setString(7, row.getOrDefault("zipcode", ""));
                        ps.addBatch(); count++;
                    } catch (Exception ignored) { skipped++; }
                    if (count % 1000 == 0) ps.executeBatch();
                }
                ps.executeBatch();
                break;
        }

        conn.commit();
        conn.setAutoCommit(true);
        return new int[]{count, skipped};
    }

    private int parseInt(Object v) { try { return Integer.parseInt(String.valueOf(v)); } catch(Exception e) { return 0; } }
    private long parseLong(Object v) { try { return Long.parseLong(String.valueOf(v)); } catch(Exception e) { return 0L; } }
    private double parseDouble(Object v) { try { return Double.parseDouble(String.valueOf(v)); } catch(Exception e) { return 0.0; } }
}
