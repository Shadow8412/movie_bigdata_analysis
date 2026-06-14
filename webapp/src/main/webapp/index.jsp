<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>电影评分大数据分析系统</title>
    <script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: "Microsoft YaHei", "PingFang SC", sans-serif; background: #f0f2f5; color: #333; }
        .header {
            background: linear-gradient(135deg, #1a237e, #283593, #3949ab);
            color: #fff; padding: 16px 32px;
            display: flex; justify-content: space-between; align-items: center;
            box-shadow: 0 2px 8px rgba(0,0,0,.2);
        }
        .header h1 { font-size: 22px; font-weight: 600; }
        .header .info { font-size: 13px; opacity: .85; }
        .header .nav { display: flex; gap: 12px; align-items: center; }
        .nav-btn { display: inline-block; padding: 10px 20px; border-radius: 22px; color: #fff; text-decoration: none; font-size: 15px; font-weight: 500; transition: all .2s; background: rgba(255,255,255,0.12); }
        .nav-btn:hover { background: rgba(255,255,255,0.25); transform: translateY(-1px); }
        .nav-btn.active { background: #ffeb3b; color: #1a237e; font-weight: 700; }
        .nav-spacer { flex: 1; }
        .container { max-width: 1400px; margin: 20px auto; padding: 0 16px; }
        .stats-row {
            display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: #fff; border-radius: 8px; padding: 20px; text-align: center;
            box-shadow: 0 1px 4px rgba(0,0,0,.06);
        }
        .stat-card .value { font-size: 28px; font-weight: bold; color: #1a237e; }
        .stat-card .label { font-size: 13px; color: #888; margin-top: 4px; }
        .charts-grid {
            display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px;
        }
        .chart-card {
            background: #fff; border-radius: 8px; padding: 16px;
            box-shadow: 0 1px 4px rgba(0,0,0,.06);
        }
        .chart-card.full { grid-column: span 2; }
        .chart-card h3 {
            font-size: 15px; color: #1a237e; margin-bottom: 12px;
            padding-bottom: 8px; border-bottom: 2px solid #e8e8e8;
        }
        .chart-box { width: 100%; height: 420px; }
        .chart-box.tall { height: 550px; }
        .footer { text-align: center; color: #999; font-size: 12px; padding: 16px; margin-top: 16px; }
        .loading { text-align: center; color: #999; padding: 40px; }
    </style>
</head>
<body>

<div class="header">
    <div>
        <h1>电影评分大数据分析系统</h1>
        <div class="info">基于 Hadoop + Hive + Spark + MySQL + ECharts | 数据集: <span id="headerDs">MovieLens 1M</span></div>
    </div>
    <div class="info">大数据系统及应用课程设计</div>
    <div class="nav">
        <select id="dsSelector" style="padding:8px 12px;border-radius:22px;font-size:14px;border:none;background:rgba(255,255,255,0.15);color:#fff;outline:none;cursor:pointer;" onchange="switchDataset(this.value)">
            <option value="0" style="color:#333;">MovieLens 1M (默认)</option>
        </select>
        <a href="ai_analysis.jsp" class="nav-btn">🤖 AI 评鉴</a>
        <a href="upload.jsp" class="nav-btn">📤 上传</a>
        <a href="datasets.jsp" class="nav-btn">🗂️ 管理</a>
    </div>
</div>

<div class="container">
    <!-- 统计概览 -->
    <div class="stats-row" id="statsRow">
        <div class="stat-card"><div class="value">-</div><div class="label">电影总数</div></div>
        <div class="stat-card"><div class="value">-</div><div class="label">评分总数</div></div>
        <div class="stat-card"><div class="value">-</div><div class="label">用户总数</div></div>
        <div class="stat-card"><div class="value">-</div><div class="label">综合平均分</div></div>
    </div>

    <!-- 图表区域 -->
    <div class="charts-grid">
        <!-- 3.1 评分分布柱状图 -->
        <div class="chart-card">
            <h3>评分整体分布</h3>
            <div class="chart-box" id="chartRatingDist"></div>
        </div>

        <!-- 3.2 热门电影TOP20 -->
        <div class="chart-card">
            <h3>热门电影 TOP20 (平均评分)</h3>
            <div class="chart-box" id="chartTopMovies"></div>
        </div>

        <!-- 3.3 电影类别统计 -->
        <div class="chart-card">
            <h3>电影类别数量分布</h3>
            <div class="chart-box" id="chartGenreDist"></div>
        </div>

        <!-- 3.4 男女用户评分对比 -->
        <div class="chart-card">
            <h3>男女用户评分对比</h3>
            <div class="chart-box" id="chartGenderComp"></div>
        </div>

        <!-- 3.5 年龄段分析 -->
        <div class="chart-card">
            <h3>各年龄段用户评分行为</h3>
            <div class="chart-box" id="chartAgeStats"></div>
        </div>

        <!-- 3.6 职业分析 -->
        <div class="chart-card">
            <h3>各职业用户评分统计</h3>
            <div class="chart-box" id="chartOccStats"></div>
        </div>

        <!-- 3.7 活跃用户 -->
        <div class="chart-card full">
            <h3>最活跃用户 TOP20</h3>
            <div class="chart-box tall" id="chartActiveUsers"></div>
        </div>
    </div>
</div>

<div class="footer">
    <p>电影评分大数据分析系统 | Hadoop + Hive + Spark + MySQL + ECharts</p>
    <p>湖南工业大学 计算机学院 大数据系统及应用课程设计</p>
</div>

<script>
// ======================================================================
//  ECharts 仪表板 — 支持多数据集切换
// ======================================================================
var currentDs = 0;
// Read ds from URL param
var urlParams = new URLSearchParams(window.location.search);
if (urlParams.has('ds')) currentDs = parseInt(urlParams.get('ds'));

// Load available datasets into dropdown
fetch('/movie-analysis/api/data?type=datasets')
    .then(r => r.json())
    .then(function(data) {
        var sel = document.getElementById('dsSelector');
        sel.innerHTML = '';
        data.forEach(function(d) {
            sel.innerHTML += '<option value="' + d.id + '" style="color:#333;"' +
                (d.id == currentDs ? ' selected' : '') + '>' +
                d.name + ' (' + d.rating_count + ' ratings)</option>';
            // Update header with current dataset name
            if (d.id == currentDs) {
                document.getElementById('headerDs').textContent = d.name;
            }
        });
        // Fallback: if currentDs not found, use first
        if (currentDs == 0 || currentDs == 1) {
            document.getElementById('headerDs').textContent = data[0] ? data[0].name : 'MovieLens 1M';
        }
    });

function switchDataset(dsId) {
    window.location.href = '/movie-analysis/?ds=' + dsId;
}

// ==================== 通用工具 ====================
function formatCount(n) {
    n = parseInt(n);
    if (n >= 10000) return (n / 10000).toFixed(1) + '万';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
    return n.toLocaleString();
}
function fetchData(type, callback) {
    fetch('/movie-analysis/api/data?type=' + type + '&ds=' + currentDs)
        .then(res => res.json())
        .then(data => callback(data))
        .catch(err => console.error(type + ': ' + err));
}

function initChart(domId) {
    return echarts.init(document.getElementById(domId));
}

// ==================== 0. 仪表板汇总统计 ====================
// 数据源: /api/data?type=summary → dashboard_summary 表
// 更新: 4 个 stat-card (电影总数/评分总数/用户总数/综合平均分)
fetchData('summary', function(data) {
    if (data.length > 0) {
        var s = data[0];
        document.querySelectorAll('#statsRow .stat-card')[0].querySelector('.value').textContent
            = parseInt(s.total_movies).toLocaleString();
        document.querySelectorAll('#statsRow .stat-card')[1].querySelector('.value').textContent
            = formatCount(s.total_ratings);
        document.querySelectorAll('#statsRow .stat-card')[2].querySelector('.value').textContent
            = parseInt(s.total_users);
        document.querySelectorAll('#statsRow .stat-card')[3].querySelector('.value').textContent
            = parseFloat(s.avg_rating).toFixed(2);
    }
});

// ==================== 1. 评分分布柱状图 ====================
// 数据源: /api/data?type=rating_dist → rating_distribution 表
// 图表: x轴=1~5分, y轴=评分数量, 渐变柱状图 + 平均值标线
fetchData('rating_dist', function(data) {
    var chart = initChart('chartRatingDist');
    var scores = data.map(d => d.score + '分');
    var counts = data.map(d => parseInt(d.count));
    chart.setOption({
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        xAxis: { type: 'category', data: scores, name: '评分' },
        yAxis: { type: 'value', name: '数量',
            axisLabel: { formatter: v => v >= 10000 ? (v/10000).toFixed(0) + 'w' : v } },
        series: [{
            type: 'bar', data: counts,
            itemStyle: { color: new echarts.graphic.LinearGradient(0,0,0,1,[
                {offset:0, color:'#667eea'}, {offset:1, color:'#764ba2'}
            ])},
            markLine: { 
                data: [{ type: 'average', name: '平均值' }],
                label: { position: 'insideEndTop', fontSize: 11 }
            }
        }],
        grid: { left: 65, right: 35, top: 35, bottom: 35, containLabel: true }
    });
});

// ==================== 2. 热门电影 TOP20 水平条形图 ====================
// 数据源: /api/data?type=top_movies → top_movies 表
// 图表: y轴=电影名, x轴=平均评分, 水平渐变条形图 + 右侧数值标签
fetchData('top_movies', function(data) {
    var chart = initChart('chartTopMovies');
    var movies = data.map(d => d.movie_name).reverse();
    var ratings = data.map(d => parseFloat(d.avg_rating)).reverse();
    var counts = data.map(d => d.rating_count).reverse();
    var minR = Math.max(0, (Math.min.apply(null, ratings) - 0.5).toFixed(1));
    var maxR = (Math.max.apply(null, ratings) + 0.3).toFixed(1);
    chart.setOption({
        tooltip: {
            trigger: 'axis',
            formatter: function(params) {
                var i = params[0].dataIndex;
                return movies[i] + '<br/>平均分: ' + ratings[i] + '<br/>评分人数: ' + counts[i];
            }
        },
        xAxis: { type: 'value', name: '平均评分', nameLocation: 'center', nameGap: 25,
            min: minR, max: maxR },
        yAxis: { type: 'category', data: movies,
            axisLabel: { fontSize: 11,
                formatter: function(v) { return v.length > 25 ? v.substring(0,23) + '...' : v; }
            }
        },
        series: [{
            type: 'bar', data: ratings,
            itemStyle: { color: new echarts.graphic.LinearGradient(0,0,1,0,[
                {offset:0, color:'#43e97b'}, {offset:1, color:'#38f9d7'}
            ])},
            label: { show: true, position: 'right', fontSize: 10, formatter: '{c}' }
        }],
        grid: { left: 5, right: 60, top: 5, bottom: 30, containLabel: true }
    });
});

// ==================== 3. 电影类别分布玫瑰饼图 ====================
// 数据源: /api/data?type=genre_stats → genre_stats 表 (取前10)
// 图表: ECharts 玫瑰饼图 (roseType:area), 显示各类别电影数量占比
fetchData('genre_stats', function(data) {
    var chart = initChart('chartGenreDist');
    var top10 = data.slice(0, 10);
    chart.setOption({
        tooltip: {
            trigger: 'item',
            formatter: '{b}: {c} 部 ({d}%)'
        },
        series: [{
            type: 'pie',
            radius: ['45%', '75%'],
            center: ['50%', '55%'],
            roseType: 'area',
            itemStyle: { borderRadius: 4 },
            data: top10.map(d => ({ name: d.genre_name, value: parseInt(d.movie_count) })),
            label: { fontSize: 10 },
            emphasis: {
                itemStyle: { shadowBlur: 10, shadowOffsetX: 0, shadowColor: 'rgba(0,0,0,0.3)' }
            }
        }]
    });
});

// ==================== 4. 男女用户评分对比组合图 ====================
// 数据源: /api/data?type=gender_comp → gender_comparison 表
// 图表: 双柱(用户数+评分量) + 双线(均分+好评率), 双Y轴
fetchData('gender_comp', function(data) {
    var chart = initChart('chartGenderComp');
    chart.setOption({
        tooltip: { trigger: 'axis' },
        legend: { data: ['用户数', '评分量(万)', '平均评分', '好评率(%)'] },
        xAxis: { type: 'category', data: data.map(d => d.gender) },
        yAxis: [
            { type: 'value', name: '数量' },
            { type: 'value', name: '评分/百分比' }
        ],
        series: [
            { name: '用户数', type: 'bar', data: data.map(d => parseInt(d.user_count)),
                itemStyle: { color: '#5470c6' } },
            { name: '评分量', type: 'bar', data: data.map(d => parseInt(d.rating_count)),
                itemStyle: { color: '#91cc75' } },
            { name: '平均评分', type: 'line', yAxisIndex: 1,
                data: data.map(d => parseFloat(d.avg_rating)),
                itemStyle: { color: '#ee6666' } },
            { name: '好评率(%)', type: 'line', yAxisIndex: 1,
                data: data.map(d => parseFloat(d.high_rate_pct)),
                itemStyle: { color: '#fac858' } }
        ],
        grid: { left: 60, right: 60, top: 40, bottom: 30, containLabel: true }
    });
});

// ==================== 5. 各年龄段分析组合图 ====================
// 数据源: /api/data?type=age_stats → age_group_stats 表
// 图表: 双柱(用户数+评分量) + 折线(平均评分), 6个年龄段
fetchData('age_stats', function(data) {
    var chart = initChart('chartAgeStats');
    chart.setOption({
        tooltip: { trigger: 'axis' },
        legend: { data: ['用户数', '评分量(万)', '平均评分'] },
        xAxis: { type: 'category', data: data.map(d => d.age_group) },
        yAxis: [
            { type: 'value', name: '数量' },
            { type: 'value', name: '平均评分', min: 3.0, max: 4.5 }
        ],
        series: [
            { name: '用户数', type: 'bar', data: data.map(d => parseInt(d.user_count)),
                itemStyle: { color: '#3b82f6' }, barGap: '10%' },
            { name: '评分量', type: 'bar', data: data.map(d => parseInt(d.rating_count)),
                itemStyle: { color: '#60a5fa' } },
            { name: '平均评分', type: 'line', yAxisIndex: 1,
                data: data.map(d => parseFloat(d.avg_rating)),
                symbol: 'circle', symbolSize: 10,
                lineStyle: { width: 3, color: '#f97316' },
                itemStyle: { color: '#f97316' } }
        ],
        grid: { left: 60, right: 60, top: 40, bottom: 30, containLabel: true }
    });
});

// ==================== 6. 各职业分析组合图 ====================
// 数据源: /api/data?type=occupation_stats → occupation_stats 表 (前15)
// 图表: 柱状(评分总量) + 折线(人均评分), x轴旋转45°
fetchData('occupation_stats', function(data) {
    var chart = initChart('chartOccStats');
    var top = data.slice(0, 15);
    chart.setOption({
        tooltip: { trigger: 'axis' },
        legend: { data: ['评分总量', '人均评分量'] },
        xAxis: {
            type: 'category',
            data: top.map(d => d.occupation),
            axisLabel: { rotate: 45, fontSize: 10 }
        },
        yAxis: [
            { type: 'value', name: '评分数量' },
            { type: 'value', name: '人均评分' }
        ],
        series: [
            { name: '评分总量', type: 'bar', yAxisIndex: 0,
                data: top.map(d => parseInt(d.rating_count)),
                itemStyle: { color: '#8b5cf6' } },
            { name: '人均评分量', type: 'line', yAxisIndex: 1,
                data: top.map(d => parseFloat(d.rating_per_user)),
                itemStyle: { color: '#ec4899' }, symbol: 'diamond' }
        ],
        grid: { left: 60, right: 60, top: 40, bottom: 80, containLabel: true }
    });
});

// ==================== 7. 最活跃用户 TOP20 ====================
// 数据源: /api/data?type=active_users → active_users 表
// 图表: 彩色条形图 + dataZoom 滑块缩放, tooltip 显示用户详情
fetchData('active_users', function(data) {
    var chart = initChart('chartActiveUsers');
    var labels = data.map(d => '用户#' + d.user_id);
    var counts = data.map(d => parseInt(d.rating_count));
    chart.setOption({
        tooltip: {
            trigger: 'axis',
            formatter: function(ps) {
                var d = data[ps[0].dataIndex];
                return '用户#' + d.user_id +
                    ' (' + d.gender + ', ' + d.age + '岁, ' + d.occupation + ')' +
                    '<br/>评分数: ' + d.rating_count +
                    '<br/>平均分: ' + d.avg_rating;
            }
        },
        xAxis: { type: 'category', data: labels, axisLabel: { rotate: 60, fontSize: 10 } },
        yAxis: { type: 'value', name: '评分数量', nameLocation: 'center', nameGap: 45,
            axisLabel: { formatter: v => v >= 1000 ? (v/1000).toFixed(0) + 'k' : v } },
        series: [{
            type: 'bar', data: counts,
            itemStyle: {
                color: function(params) {
                    var colors = ['#667eea','#764ba2','#f093fb','#f5576c','#4facfe',
                                  '#00f2fe','#43e97b','#38f9d7','#fa709a','#fee140'];
                    return colors[params.dataIndex % colors.length];
                }
            }
        }],
        dataZoom: [{ type: 'slider', start: 0, end: 100, height: 20, bottom: 10 }],
        grid: { left: 80, right: 30, top: 20, bottom: 120, containLabel: true }
    });
});

// 响应式图表
window.addEventListener('resize', function() {
    ['chartRatingDist','chartTopMovies','chartGenreDist','chartGenderComp',
     'chartAgeStats','chartOccStats','chartActiveUsers'].forEach(function(id) {
        var dom = document.getElementById(id);
        if (dom) {
            var instance = echarts.getInstanceByDom(dom);
            if (instance) instance.resize();
        }
    });
});
</script>
</body>
</html>
