package com.movie.analysis.servlet;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.movie.analysis.dao.DatabaseConnector;

/**
 * 数据 RESTful API Servlet — 仪表板后端核心控制器
 * =================================================================
 * 架构: 前端 index.jsp → fetch(/api/data?type=xxx&ds=N) → DataServlet → MySQL → JSON → ECharts
 *
 * 全部 13 个 API 端点:
 *   数据查询 (8):
 *     GET /api/data?type=summary           → 仪表板汇总 (电影/评分/用户总数/均分)
 *     GET /api/data?type=rating_dist       → 评分1-5分布 (柱状图)
 *     GET /api/data?type=top_movies        → 热门电影TOP20 (水平条形图)
 *     GET /api/data?type=genre_stats       → 电影类别统计 (玫瑰饼图)
 *     GET /api/data?type=active_users      → 活跃用户TOP20 (彩色条形图+dataZoom)
 *     GET /api/data?type=gender_comp       → 男女评分对比 (双柱+双线组合图)
 *     GET /api/data?type=age_stats         → 年龄段分析 (6组年龄段双Y轴)
 *     GET /api/data?type=occupation_stats  → 职业分析 (柱+折线, x轴旋转45度)
 *
 *   数据集管理 (3):
 *     GET /api/data?type=datasets          → 所有数据集列表 (用于下拉框+管理页)
 *     GET /api/data?type=dataset_status&ds=N → Spark完成状态 (ready/analyzing)
 *     GET /api/data?type=delete_dataset&ds=N → 删除数据集 (DROP表+清理VM文件)
 *
 * 多数据集切换:
 *   ?ds=0 或 ?ds=1 或 无参数 → 默认MovieLens (空前缀)
 *   ?ds=N (N>1)              → ds{N}_ 前缀的自定义数据集
 *
 * 数据流: MySQL (movie_analysis) ← Spark 分析 / Hive 分析 / CsvImporter SQL导入
 * 安全: Access-Control-Allow-Origin:* (开发阶段允许跨域)
 * =================================================================
 */
public class DataServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        req.setCharacterEncoding("UTF-8");
        resp.setCharacterEncoding("UTF-8");
        resp.setContentType("application/json;charset=UTF-8");

        resp.setHeader("Access-Control-Allow-Origin", "*");

        String type = req.getParameter("type");
        if (type == null || type.isEmpty()) {
            resp.getWriter().write("{\"error\":\"missing type parameter\"}");
            return;
        }

        // Dataset switching: ?ds=N  (null/0/1=default MovieLens, N>1=custom dataset)
        String dsId = req.getParameter("ds");
        boolean custom = dsId != null && !"0".equals(dsId) && !"1".equals(dsId);
        String prefix = custom ? ("ds" + dsId + "_") : "";

        String json = "";
        switch (type) {
            case "rating_dist":
                json = DatabaseConnector.queryToJson(
                    "SELECT score, count, percentage FROM " + prefix + "rating_distribution ORDER BY score",
                    new String[]{"score", "count", "percentage"});
                break;

            case "top_movies":
                json = DatabaseConnector.queryToJson(
                    "SELECT movie_name, avg_rating, rating_count FROM " + prefix + "top_movies ORDER BY avg_rating DESC LIMIT 20",
                    new String[]{"movie_name", "avg_rating", "rating_count"});
                break;

            case "genre_stats":
                json = DatabaseConnector.queryToJson(
                    "SELECT genre_name, movie_count, avg_rating, rating_count FROM " + prefix + "genre_stats ORDER BY movie_count DESC",
                    new String[]{"genre_name", "movie_count", "avg_rating", "rating_count"});
                break;

            case "active_users":
                json = DatabaseConnector.queryToJson(
                    "SELECT user_id, COALESCE(gender,'?') AS gender, " +
                    "CAST(COALESCE(`age`,0) AS CHAR) AS age, " +
                    "COALESCE(occupation,'?') AS occupation, rating_count, avg_rating FROM " +
                    prefix + "active_users ORDER BY rating_count DESC",
                    new String[]{"user_id", "gender", "age", "occupation", "rating_count", "avg_rating"});
                break;

            case "gender_comp":
                json = DatabaseConnector.queryToJson(
                    "SELECT gender, user_count, rating_count, avg_rating, high_rate_pct FROM " + prefix + "gender_comparison",
                    new String[]{"gender", "user_count", "rating_count", "avg_rating", "high_rate_pct"});
                break;

            case "age_stats":
                json = DatabaseConnector.queryToJson(
                    "SELECT age_group, user_count, rating_count, avg_rating FROM " + prefix + "age_group_stats ORDER BY FIELD(age_group,'Under18','19-25','26-35','36-45','46-55','56+')",
                    new String[]{"age_group", "user_count", "rating_count", "avg_rating"});
                break;

            case "occupation_stats":
                json = DatabaseConnector.queryToJson(
                    "SELECT occupation, user_count, rating_count, avg_rating, rating_per_user FROM " + prefix + "occupation_stats ORDER BY rating_count DESC LIMIT 20",
                    new String[]{"occupation", "user_count", "rating_count", "avg_rating", "rating_per_user"});
                break;

            case "summary":
                json = DatabaseConnector.queryToJson(
                    "SELECT total_movies, total_ratings, total_users, avg_rating FROM " + prefix + "dashboard_summary LIMIT 1",
                    new String[]{"total_movies", "total_ratings", "total_users", "avg_rating"});
                break;

            case "datasets":
                json = DatabaseConnector.queryToJson(
                    "SELECT id, name, movie_count, rating_count, user_count FROM datasets ORDER BY id",
                    new String[]{"id", "name", "movie_count", "rating_count", "user_count"});
                break;

            // Check if Spark has completed for a dataset (has dashboard_summary table)
            case "dataset_status":
                String ds = req.getParameter("ds");
                if (ds == null || ds.equals("0") || ds.equals("1")) {
                    json = "{\"status\":\"ready\"}";
                } else {
                    json = DatabaseConnector.queryToJson(
                        "SELECT COUNT(*) AS cnt FROM ds" + ds + "_dashboard_summary",
                        new String[]{"cnt"});
                    if (json.contains("\"cnt\":0") || json.contains("\"error\"")) {
                        json = "{\"status\":\"analyzing\"}";
                    } else {
                        json = "{\"status\":\"ready\"}";
                    }
                }
                break;

            // Delete a custom dataset (N>1)
            case "delete_dataset":
                String delDs = req.getParameter("ds");
                json = deleteDataset(delDs);
                break;

            default:
                json = "{\"error\":\"未知的 type: " + type + "\"}";
        }

        resp.getWriter().write(json);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        doGet(req, resp);
    }

    /** Delete a custom dataset: drop tables + remove dataset record + clean VM files */
    private String deleteDataset(String dsId) {
        if (dsId == null || dsId.equals("0") || dsId.equals("1")) {
            return "{\"error\":\"不能删除默认数据集\"}";
        }
        try {
            java.sql.Connection conn = DatabaseConnector.getConnection();
            java.sql.Statement stmt = conn.createStatement();
            // Drop all ds{N}_* tables
            String prefix = "ds" + dsId + "_";
            java.sql.ResultSet rs = stmt.executeQuery(
                "SELECT TABLE_NAME FROM information_schema.TABLES" +
                " WHERE TABLE_SCHEMA='movie_analysis' AND TABLE_NAME LIKE '" + prefix + "%'");
            java.util.List<String> tables = new java.util.ArrayList<>();
            while (rs.next()) tables.add(rs.getString(1));
            for (String t : tables) stmt.executeUpdate("DROP TABLE IF EXISTS `" + t + "`");
            // Remove from datasets table
            stmt.executeUpdate("DELETE FROM datasets WHERE id=" + dsId);
            rs.close();
            stmt.close();
            conn.close();
            // Clean VM data directory
            try {
                Runtime.getRuntime().exec(new String[]{
                    "ssh", "my-hadoop",
                    "rm -rf ~/movie_bigdata_analysis/data/custom/ds" + dsId
                });
            } catch (Exception ignored) {}
            return "{\"success\":true,\"message\":\"数据集 ID=" + dsId + " 已删除 (共 " + tables.size() + " 张表)\"}";
        } catch (Exception e) {
            return "{\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}";
        }
    }
}
