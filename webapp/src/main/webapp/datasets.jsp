<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>数据集管理 — 电影评分大数据分析系统</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🎬</text></svg>">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: "Microsoft YaHei","PingFang SC",sans-serif; background: #f0f2f5; color: #333; }
        .header { background: linear-gradient(135deg,#1a237e,#283593,#3949ab); color:#fff; padding:16px 32px; box-shadow:0 2px 8px rgba(0,0,0,.2); }
        .header h1 { font-size:22px; }
        .header .sub { font-size:13px; opacity:.85; }
        .header .nav { display:flex; gap:12px; align-items:center; }
        .nav-btn { display:inline-block; padding:10px 20px; border-radius:22px; color:#fff; text-decoration:none; font-size:15px; font-weight:500; transition:all .2s; background:rgba(255,255,255,0.12); }
        .nav-btn:hover { background:rgba(255,255,255,0.25); transform:translateY(-1px); }
        .nav-btn.active { background:#ffeb3b; color:#1a237e; font-weight:700; }
        .container { max-width:1000px; margin:24px auto; padding:0 16px; }
        .card { background:#fff; border-radius:8px; padding:24px; box-shadow:0 1px 4px rgba(0,0,0,.06); margin-bottom:20px; }
        .card h2 { font-size:18px; color:#1a237e; margin-bottom:16px; }
        table { width:100%; border-collapse:collapse; font-size:14px; }
        th { text-align:left; padding:10px 12px; border-bottom:2px solid #e0e0e0; color:#888; font-size:12px; font-weight:600; }
        td { padding:10px 12px; border-bottom:1px solid #f0f0f0; }
        tr:hover { background:#f8f9ff; }
        .btn-sm { padding:5px 14px; border-radius:4px; border:none; cursor:pointer; font-size:12px; text-decoration:none; display:inline-block; }
        .btn-view { background:#3949ab; color:#fff; }
        .btn-view:hover { background:#283593; }
        .btn-del { background:#fff; color:#e53935; border:1px solid #e53935; margin-left:6px; }
        .btn-del:hover { background:#e53935; color:#fff; }
        .badge { font-size:11px; padding:2px 8px; border-radius:10px; background:#e8eaf6; color:#3949ab; }
        .empty { text-align:center; color:#999; padding:40px; }
        .toast { position:fixed; top:16px; left:50%; transform:translateX(-50%); padding:8px 20px; border-radius:20px; font-size:13px; font-weight:600; z-index:999; }
        .toast.ok { background:#4caf50; color:#fff; }
        .toast.err { background:#f44336; color:#fff; }
    </style>
</head>
<body>
<div class="header">
    <div>
        <h1>🗂️ 数据集管理</h1>
        <div class="sub">管理已上传的自定义数据集</div>
    </div>
    <div class="nav">
        <a href="index.jsp" class="nav-btn">📊 仪表板</a>
        <a href="ai_analysis.jsp" class="nav-btn">🤖 AI 评鉴</a>
        <a href="upload.jsp" class="nav-btn">📤 上传</a>
        <a href="datasets.jsp" class="nav-btn active">🗂️ 管理</a>
    </div>
</div>

<div class="container">
    <div class="card">
        <h2>📋 所有数据集</h2>
        <div id="datasetList" style="color:#999;">加载中...</div>
    </div>
</div>

<script>
function loadDatasets() {
    fetch('/movie-analysis/api/data?type=datasets')
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.length === 0) {
                document.getElementById('datasetList').innerHTML = '<div class="empty">📭 暂无数据集</div>';
                return;
            }
            var html = '<table><thead><tr>' +
                '<th>名称</th><th style="text-align:center;">电影</th><th style="text-align:center;">评分</th>' +
                '<th style="text-align:center;">用户</th><th style="text-align:center;">状态</th>' +
                '<th style="text-align:right;">操作</th></tr></thead><tbody>';
            data.forEach(function(d) {
                var isDefault = d.id == 1;
                var hasData = (d.rating_count || 0) > 0;
                var status = isDefault ? '<span class="badge">默认</span>' :
                             (hasData ? '<span class="badge" style="background:#e8f5e9;color:#2e7d32;">✅ 已分析</span>' :
                                        '<span class="badge" style="background:#fff3e0;color:#e65100;">⏳ 未分析</span>');
                html += '<tr>' +
                    '<td><strong>' + (isDefault ? '⭐ ' : '📁 ') + d.name + '</strong>' +
                        (isDefault ? ' <small style="color:#888;">(系统内置)</small>' : '') +
                        '<br><small style="color:#aaa;">ID: ' + d.id + '</small></td>' +
                    '<td style="text-align:center;">' + (d.movie_count || 0) + '</td>' +
                    '<td style="text-align:center;">' + (d.rating_count || 0) + '</td>' +
                    '<td style="text-align:center;">' + (d.user_count || 0) + '</td>' +
                    '<td style="text-align:center;">' + status + '</td>' +
                    '<td style="text-align:right;">' +
                        '<a href="index.jsp?ds=' + d.id + '" class="btn-sm btn-view">查看</a>' +
                        (!isDefault ? '<button class="btn-sm btn-del" onclick="del(' + d.id + ',\'' + d.name + '\')">删除</button>' : '') +
                    '</td></tr>';
            });
            html += '</tbody></table>';
            document.getElementById('datasetList').innerHTML = html;
        });
}

function del(id, name) {
    if (!confirm('确定删除「' + name + '」(ID=' + id + ') 吗？\n\n此操作不可恢复！')) return;
    fetch('/movie-analysis/api/data?type=delete_dataset&ds=' + id)
        .then(function(r) { return r.json(); })
        .then(function(d) {
            toast(d.success ? '✅ ' + d.message : '❌ ' + (d.error||'失败'), d.success);
            if (d.success) loadDatasets();
        });
}

function toast(msg, ok) {
    var t = document.createElement('div');
    t.className = 'toast ' + (ok ? 'ok' : 'err');
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function() { t.remove(); }, 2500);
}

loadDatasets();
</script>
</body>
</html>
