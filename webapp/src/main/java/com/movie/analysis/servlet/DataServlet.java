package com.movie.analysis.servlet;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.movie.analysis.dao.DatabaseConnector;

/**
 * 数据 RESTful API Servlet — 后端核心控制器
 * 负责成员: E (数据可视化)
 * =================================================================
 * 功能: 提供 JSON 格式的数据接口，供前端 ECharts 通过 AJAX fetch 获取分析数据。
 * 架构: 前端 index.jsp → fetch(/api/data?type=xxx) → DataServlet → MySQL → JSON → ECharts
 *
 * 全部 8 个 API 端点:
 *   GET /api/data?type=summary           → 仪表板汇总 (电影/评分/用户总数、均分)
 *   GET /api/data?type=rating_dist       → 评分1-5分布 (柱状图)
 *   GET /api/data?type=top_movies        → 热门电影TOP20 (水平条形图)
 *   GET /api/data?type=genre_stats       → 电影类别统计 (饼图)
 *   GET /api/data?type=active_users      → 活跃用户TOP20 (条形图+缩放)
 *   GET /api/data?type=gender_comp       → 男女评分对比 (组合图)
 *   GET /api/data?type=age_stats         → 年龄段分析 (组合图)
 *   GET /api/data?type=occupation_stats  → 职业分析 (组合图)
 *
 * 数据流: MySQL (movie_analysis) ← Hive 分析 / Spark 分析
 * 安全: 设置 Access-Control-Allow-Origin:* 允许跨域 (开发用)
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

        // Dataset switching: ?ds=N  (0=default MovieLens, N=uploaded dataset ID)
        String dsId = req.getParameter("ds");
        boolean custom = dsId != null && !"0".equals(dsId);
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
}
