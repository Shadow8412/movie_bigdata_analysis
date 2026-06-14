package com.movie.analysis.servlet;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.movie.analysis.dao.DatabaseConnector;

/**
 * AI 电影评鉴师 Servlet — 代理转发 AI API 请求
 * 负责: 接收前端 JSON → 注入数据集上下文 → 转发 AI API → 返回结果
 *
 * POST /api/ai
 * Body: { "apiKey":"sk-xxx", "endpoint":"https://api.openai.com", "model":"gpt-4o",
 *         "messages":[{"role":"user","content":"..."}], "datasetId":"0" }
 */
public class AiAnalysisServlet extends HttpServlet {

    private static final String MOVIE_CRITIC_PROMPT =
        "你是一位资深的电影评鉴师，名叫「光影先生」。你拥有以下特质：\n" +
        "- 对世界电影史了如指掌，从默片时代到当代数字电影\n" +
        "- 精通电影理论、导演风格、表演艺术、摄影美学\n" +
        "- 对 IMDb Top250、豆瓣 Top250 等榜单如数家珍\n" +
        "- 善于从数据中发现电影艺术与观众口味的关联\n" +
        "- 回答问题时优雅、专业、引经据典，偶尔提及经典电影桥段\n" +
        "- 可以用中文流畅交流，但对电影名称同时给出中英文\n\n" +
        "你的任务是基于提供的数据集分析结果，以电影评鉴师的视角进行深度解读和分析。";

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, java.io.IOException {

        req.setCharacterEncoding("UTF-8");
        resp.setCharacterEncoding("UTF-8");
        resp.setContentType("application/json;charset=UTF-8");
        resp.setHeader("Access-Control-Allow-Origin", "*");

        // 读取请求体
        StringBuilder body = new StringBuilder();
        try (BufferedReader reader = req.getReader()) {
            String line;
            while ((line = reader.readLine()) != null) {
                body.append(line);
            }
        }

        // 简单 JSON 解析（避免依赖第三方库）
        String jsonStr = body.toString();
        String apiKey   = extractJsonString(jsonStr, "apiKey");
        String endpoint = extractJsonString(jsonStr, "endpoint");
        String model    = extractJsonString(jsonStr, "model");
        String messagesStr = extractJsonRaw(jsonStr, "messages");
        String datasetId = extractJsonString(jsonStr, "datasetId");

        if (apiKey == null || apiKey.isEmpty()) {
            resp.getWriter().write("{\"error\":\"请提供 API Key\"}");
            return;
        }
        if (endpoint == null || endpoint.isEmpty()) {
            endpoint = "https://api.openai.com";
        }
        if (model == null || model.isEmpty()) {
            model = "gpt-4o";
        }

        // 构建系统提示 + 数据集上下文
        String systemContent = MOVIE_CRITIC_PROMPT;
        if (datasetId != null && !datasetId.isEmpty() && !"0".equals(datasetId)) {
            systemContent += "\n\n" + buildDatasetContext(datasetId);
        } else {
            // 默认 MovieLens 1M
            systemContent += "\n\n" + buildDatasetContext("0");
        }

        // 构建 OpenAI 兼容请求
        StringBuilder aiReq = new StringBuilder();
        aiReq.append("{");
        aiReq.append("\"model\":\"").append(escapeJson(model)).append("\",");
        aiReq.append("\"messages\":[");
        // 系统消息
        aiReq.append("{\"role\":\"system\",\"content\":\"").append(escapeJson(systemContent)).append("\"}");
        // 用户消息列表（messagesStr 是 JSON 数组，需去掉外层括号后逐个插入）
        if (messagesStr != null && !messagesStr.isEmpty()) {
            String inner = messagesStr.trim();
            if (inner.startsWith("[") && inner.endsWith("]")) {
                inner = inner.substring(1, inner.length() - 1).trim();
            }
            if (!inner.isEmpty()) {
                aiReq.append(",").append(inner);
            }
        } else {
            aiReq.append(",{\"role\":\"user\",\"content\":\"你好，请做一下自我介绍\"}");
        }
        aiReq.append("]}");

        // 转发到 AI API
        try {
            String apiUrl = endpoint.replaceAll("/+$", "") + "/v1/chat/completions";
            URL url = new URL(apiUrl);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            conn.setDoOutput(true);
            conn.setConnectTimeout(30000);
            conn.setReadTimeout(120000);

            try (OutputStream os = conn.getOutputStream()) {
                os.write(aiReq.toString().getBytes(StandardCharsets.UTF_8));
                os.flush();
            }

            int code = conn.getResponseCode();
            String contentType = conn.getContentType();
            if (code == 200) {
                StringBuilder aiResp = new StringBuilder();
                try (BufferedReader br = new BufferedReader(
                        new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                    String l;
                    while ((l = br.readLine()) != null) {
                        aiResp.append(l);
                    }
                }
                resp.getWriter().write(aiResp.toString());
            } else {
                // 读取错误响应
                StringBuilder errBody = new StringBuilder();
                java.io.InputStream errStream = conn.getErrorStream();
                if (errStream != null) {
                    try (BufferedReader br = new BufferedReader(
                            new InputStreamReader(errStream, StandardCharsets.UTF_8))) {
                        String l;
                        while ((l = br.readLine()) != null) {
                            errBody.append(l);
                        }
                    }
                }
                String errText = errBody.toString();
                // 检测是否是 HTML 响应（被 WAF/Cloudflare 拦截）
                if (errText.trim().startsWith("<!DOCTYPE") || errText.trim().startsWith("<html")) {
                    String hint = buildEndpointHint(endpoint);
                    resp.getWriter().write("{\"error\":\"请求被拦截 (HTTP " + code + ")。\\n" +
                        "API 端点可能配置错误，当前请求的是网页地址而非 API 地址。\\n\\n" +
                        "当前端点: " + escapeJson(endpoint) + "\\n" +
                        "请求 URL: " + escapeJson(apiUrl) + "\\n\\n" +
                        hint + "\"}");
                } else {
                    // 截断过长错误
                    if (errText.length() > 500) {
                        errText = errText.substring(0, 500) + "...";
                    }
                    resp.getWriter().write("{\"error\":\"AI API 返回 " + code + ": " +
                        escapeJson(errText) + "\"}");
                }
            }
            conn.disconnect();
        } catch (Exception e) {
            resp.getWriter().write("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, java.io.IOException {
        doPost(req, resp);
    }

    @Override
    protected void doOptions(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, java.io.IOException {
        resp.setHeader("Access-Control-Allow-Origin", "*");
        resp.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        resp.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
        resp.setStatus(200);
    }

    /** 构建数据集上下文，供 AI 分析 */
    private String buildDatasetContext(String dsId) {
        String prefix = dsId.equals("0") ? "" : ("ds" + dsId + "_");
        StringBuilder ctx = new StringBuilder();
        ctx.append("【当前分析数据集信息】\n");

        try {
            // 汇总
            String json = DatabaseConnector.queryToJson(
                "SELECT total_movies, total_ratings, total_users, avg_rating FROM " +
                prefix + "dashboard_summary LIMIT 1",
                new String[]{"total_movies","total_ratings","total_users","avg_rating"});
            if (json.startsWith("[{")) {
                ctx.append("数据集概况：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 评分分布
            String json = DatabaseConnector.queryToJson(
                "SELECT score, count, percentage FROM " + prefix +
                "rating_distribution ORDER BY score",
                new String[]{"score","count","percentage"});
            if (json.startsWith("[{")) {
                ctx.append("评分分布：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 类别统计 Top10
            String json = DatabaseConnector.queryToJson(
                "SELECT genre_name, movie_count, avg_rating, rating_count FROM " +
                prefix + "genre_stats ORDER BY movie_count DESC LIMIT 10",
                new String[]{"genre_name","movie_count","avg_rating","rating_count"});
            if (json.startsWith("[{")) {
                ctx.append("电影类别统计(Top10)：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 热门电影 Top10
            String json = DatabaseConnector.queryToJson(
                "SELECT movie_name, avg_rating, rating_count FROM " +
                prefix + "top_movies ORDER BY avg_rating DESC LIMIT 10",
                new String[]{"movie_name","avg_rating","rating_count"});
            if (json.startsWith("[{")) {
                ctx.append("热门电影(Top10)：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 性别对比
            String json = DatabaseConnector.queryToJson(
                "SELECT gender, user_count, rating_count, avg_rating, high_rate_pct FROM " +
                prefix + "gender_comparison",
                new String[]{"gender","user_count","rating_count","avg_rating","high_rate_pct"});
            if (json.startsWith("[{")) {
                ctx.append("男女评分对比：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 年龄段
            String json = DatabaseConnector.queryToJson(
                "SELECT age_group, user_count, rating_count, avg_rating FROM " +
                prefix + "age_group_stats ORDER BY FIELD(age_group,'Under18','19-25','26-35','36-45','46-55','56+')",
                new String[]{"age_group","user_count","rating_count","avg_rating"});
            if (json.startsWith("[{")) {
                ctx.append("年龄段分析：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        try {
            // 职业 Top10
            String json = DatabaseConnector.queryToJson(
                "SELECT occupation, user_count, rating_count, avg_rating FROM " +
                prefix + "occupation_stats ORDER BY rating_count DESC LIMIT 10",
                new String[]{"occupation","user_count","rating_count","avg_rating"});
            if (json.startsWith("[{")) {
                ctx.append("职业统计(Top10)：").append(json).append("\n");
            }
        } catch (Exception ignored) {}

        return ctx.toString();
    }

    /** 根据端点 URL 给出修正提示 */
    private String buildEndpointHint(String endpoint) {
        String lower = endpoint.toLowerCase();
        if (lower.contains("platform.deepseek")) {
            return "⚠️ DeepSeek 的 API 地址是 https://api.deepseek.com ，不是 platform.deepseek.com（那是网页平台）。";
        }
        if (lower.contains("deepseek") && !lower.contains("api.deepseek")) {
            return "⚠️ DeepSeek 的正确 API 地址为: https://api.deepseek.com";
        }
        if (lower.contains("openai") && !lower.contains("api.openai")) {
            return "⚠️ OpenAI 的正确 API 地址为: https://api.openai.com";
        }
        return "💡 常见 API 端点:\n" +
               "  • OpenAI:  https://api.openai.com\n" +
               "  • DeepSeek: https://api.deepseek.com\n" +
               "  • Claude:  https://api.anthropic.com\n" +
               "请确保填写的是 API 地址而非网页平台地址。";
    }

    // ========== 简易 JSON 解析工具 ==========

    private static String extractJsonString(String json, String key) {
        String search = "\"" + key + "\"";
        int idx = json.indexOf(search);
        if (idx < 0) return null;
        idx = json.indexOf("\"", idx + search.length());
        if (idx < 0) return null;
        int start = idx + 1;
        // 找到字符串结束引号（处理转义）
        int end = start;
        while (end < json.length()) {
            char c = json.charAt(end);
            if (c == '\\') { end += 2; continue; }
            if (c == '"') break;
            end++;
        }
        return unescapeJson(json.substring(start, end));
    }

    /** 提取原始 JSON 数组/对象（不解析内部字符串） */
    private static String extractJsonRaw(String json, String key) {
        String search = "\"" + key + "\"";
        int idx = json.indexOf(search);
        if (idx < 0) return null;
        idx = json.indexOf("[", idx + search.length());
        if (idx < 0) return null;
        int depth = 0;
        int end = idx;
        for (; end < json.length(); end++) {
            char c = json.charAt(end);
            if (c == '[') depth++;
            else if (c == ']') { depth--; if (depth == 0) break; }
            else if (c == '"') {
                end++;
                while (end < json.length() && json.charAt(end) != '"') {
                    if (json.charAt(end) == '\\') end++;
                    end++;
                }
            }
        }
        return json.substring(idx, end + 1);
    }

    private static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }

    private static String unescapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\\"", "\"")
                .replace("\\\\", "\\")
                .replace("\\n", "\n")
                .replace("\\r", "\r")
                .replace("\\t", "\t");
    }
}
