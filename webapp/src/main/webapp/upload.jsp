<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>上传电影数据集 - 电影评分大数据分析系统</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: "Microsoft YaHei", "PingFang SC", sans-serif; background: #f0f2f5; color: #333; }
        .header { background: linear-gradient(135deg, #1a237e, #3949ab); color: #fff; padding: 16px 32px; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 20px; }
        .header .nav { display: flex; gap: 12px; align-items: center; }
        .nav-btn { display: inline-block; padding: 10px 20px; border-radius: 22px; color: #fff; text-decoration: none; font-size: 15px; font-weight: 500; transition: all .2s; background: rgba(255,255,255,0.12); }
        .nav-btn:hover { background: rgba(255,255,255,0.25); transform: translateY(-1px); }
        .nav-btn.active { background: #ffeb3b; color: #1a237e; font-weight: 700; }
        .header a { color: #fff; text-decoration: none; font-size: 14px; opacity: .85; }
        .container { max-width: 900px; margin: 30px auto; padding: 0 16px; }
        .card { background: #fff; border-radius: 8px; padding: 24px; box-shadow: 0 1px 4px rgba(0,0,0,.06); margin-bottom: 20px; }
        .card h2 { font-size: 16px; color: #1a237e; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid #e8e8e8; }
        .format-info { background: #e3f2fd; padding: 12px 16px; border-radius: 4px; font-size: 13px; line-height: 1.8; margin-bottom: 16px; }
        .format-info code { background: #bbdefb; padding: 1px 5px; border-radius: 2px; }
        .upload-zone {
            border: 2px dashed #ccc; border-radius: 8px; padding: 30px; text-align: center;
            cursor: pointer; transition: all .2s; margin-bottom: 16px;
        }
        .upload-zone:hover, .upload-zone.dragover { border-color: #3949ab; background: #e8eaf6; }
        .upload-zone .icon { font-size: 40px; color: #999; }
        .upload-zone p { color: #666; margin-top: 8px; }
        .btn {
            display: inline-block; padding: 10px 24px; border: none; border-radius: 4px;
            font-size: 14px; cursor: pointer; color: #fff; background: #3949ab;
            transition: background .2s; margin-right: 10px;
        }
        .btn:hover { background: #283593; }
        .btn.secondary { background: #78909c; }
        .btn.secondary:hover { background: #546e7a; }
        .file-list { margin: 12px 0; }
        .file-item { display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; background: #f5f5f5; border-radius: 4px; margin-bottom: 6px; font-size: 13px; }
        .file-item .remove { color: #e53935; cursor: pointer; font-weight: bold; }
        .result { margin-top: 16px; padding: 12px 16px; border-radius: 4px; font-size: 14px; display: none; }
        .result.success { display: block; background: #e8f5e9; color: #2e7d32; }
        .result.error { display: block; background: #ffebee; color: #c62828; }
        .result.processing { display: flex; align-items: center; gap: 12px; background: #fff3e0; color: #e65100; flex-wrap: wrap; }
        .spinner { width: 24px; height: 24px; border: 3px solid #ffe0b2; border-top: 3px solid #e65100; border-radius: 50%; animation: spin 0.8s linear infinite; flex-shrink: 0; }
        @keyframes spin { to { transform: rotate(360deg); } }
        .progress-bar { width: 100%; height: 4px; background: #ffe0b2; border-radius: 2px; margin-top: 6px; }
        .progress-fill { height: 100%; background: #e65100; border-radius: 2px; width: 5%; transition: width 0.5s; }
        .stats-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 12px; margin: 12px 0; }
        .stat-item { text-align: center; padding: 10px; background: #f5f5f5; border-radius: 4px; }
        .stat-item .num { font-size: 20px; font-weight: bold; color: #1a237e; }
        .stat-item .lbl { font-size: 11px; color: #888; }
        input[type=file] { display: none; }
    </style>
</head>
<body>
<div class="header">
    <h1>上传自定义电影数据集</h1>
    <div class="nav">
        <a href="index.jsp" class="nav-btn">📊 仪表板</a>
        <a href="ai_analysis.jsp" class="nav-btn">🤖 AI 评鉴</a>
        <a href="upload.jsp" class="nav-btn active">📤 上传</a>
        <a href="datasets.jsp" class="nav-btn">🗂️ 管理</a>
    </div>
</div>
<div class="container">

    <!-- 格式说明 -->
    <div class="card">
        <h2>📋 支持的 CSV 格式</h2>
        <div class="format-info">
            请上传 <b>至少一个</b> 包含下列列名的 CSV 文件（系统自动识别列名）：<br><br>
            <b>评分文件</b> (必需): <code>user_id, movie_id, rating</code> 或 <code>userId, movieId, rating</code><br>
            <b>电影文件</b> (可选): <code>movie_id, title</code> 或 <code>movieId, title</code><br>
            <b>用户文件</b> (可选): <code>user_id, gender, age</code> 或 <code>userId, gender, age</code><br><br>
            支持 <code>,</code> <code>::</code> <code>\t</code> 分隔符 | 支持表头自动跳过 | 单文件最大 50MB
        </div>
    </div>

    <!-- 上传区域 -->
    <div class="card">
        <h2>📤 选择文件上传</h2>
        <div style="margin-bottom:12px;">
            <label style="font-weight:bold;">数据集名称：</label>
            <input type="text" id="datasetName" placeholder="例如：我的电影评分数据" style="width:300px;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:14px;" required>
        </div>
        <form id="uploadForm" enctype="multipart/form-data">
            <div class="upload-zone" id="dropZone">
                <div class="icon">📁</div>
                <p>拖拽 CSV 文件到此处，或点击选择文件</p>
                <p style="font-size:12px;color:#aaa">支持多文件同时上传</p>
            </div>
            <input type="file" id="fileInput" name="files" multiple accept=".csv,.dat,.txt">
            <div class="file-list" id="fileList"></div>
            <button type="button" class="btn" id="uploadBtn">开始上传并处理</button>
            <button type="button" class="btn secondary" id="clearBtn">清空列表</button>
        </form>
        <div class="result" id="result"></div>
        <div class="stats-grid" id="statsGrid"></div>
    </div>

</div>

<script>
    var selectedFiles = [];

    var dropZone = document.getElementById('dropZone');
    var fileInput = document.getElementById('fileInput');
    var fileList = document.getElementById('fileList');
    var resultDiv = document.getElementById('result');
    var statsGrid = document.getElementById('statsGrid');
    var uploadBtn = document.getElementById('uploadBtn');

    // 点击上传区域触发文件选择
    dropZone.addEventListener('click', function() { fileInput.click(); });

    // 拖拽事件
    dropZone.addEventListener('dragover', function(e) { e.preventDefault(); dropZone.classList.add('dragover'); });
    dropZone.addEventListener('dragleave', function() { dropZone.classList.remove('dragover'); });
    dropZone.addEventListener('drop', function(e) {
        e.preventDefault(); dropZone.classList.remove('dragover');
        addFiles(e.dataTransfer.files);
    });

    fileInput.addEventListener('change', function() { addFiles(fileInput.files); fileInput.value = ''; });

    function addFiles(files) {
        for (var i = 0; i < files.length; i++) {
            if (files[i].name.match(/\.(csv|dat|txt)$/i)) {
                selectedFiles.push(files[i]);
            }
        }
        renderFileList();
    }

    function renderFileList() {
        fileList.innerHTML = '';
        selectedFiles.forEach(function(f, idx) {
            var div = document.createElement('div');
            div.className = 'file-item';
            div.innerHTML = '<span>' + f.name + ' (' + (f.size/1024).toFixed(1) + ' KB)</span>' +
                '<span class="remove" data-idx="' + idx + '">✕</span>';
            fileList.appendChild(div);
        });
        document.querySelectorAll('.file-item .remove').forEach(function(el) {
            el.addEventListener('click', function() {
                selectedFiles.splice(parseInt(this.dataset.idx), 1);
                renderFileList();
            });
        });
    }

    document.getElementById('clearBtn').addEventListener('click', function() {
        selectedFiles = []; renderFileList(); resultDiv.className = 'result'; resultDiv.innerHTML = ''; statsGrid.innerHTML = '';
    });

    uploadBtn.addEventListener('click', function() {
        if (selectedFiles.length === 0) { alert('请至少选择一个 CSV 文件'); return; }
        var dsName = document.getElementById('datasetName').value.trim();
        if (!dsName) { alert('请输入数据集名称'); return; }

        var formData = new FormData();
        formData.append('datasetName', dsName);
        selectedFiles.forEach(function(f) { formData.append('files', f); });

        uploadBtn.disabled = true;
        uploadBtn.textContent = '上传中...';
        resultDiv.className = 'result';
        resultDiv.innerHTML = '⏳ 正在上传文件...';
        resultDiv.style.display = 'block';
        statsGrid.innerHTML = '';

        fetch('/movie-analysis/upload', { method: 'POST', body: formData })
            .then(function(res) { return res.json(); })
            .then(function(data) {
                uploadBtn.disabled = false;
                uploadBtn.textContent = '开始上传并处理';
                if (data.success && data.datasetId) {
                    // Show processing status with spinner
                    resultDiv.className = 'result processing';
                    resultDiv.innerHTML = '<div class="spinner"></div>' +
                        '<div><strong>⏳ Spark 正在分析数据</strong>' +
                        '<br><small>' + data.message + '</small></div>' +
                        '<div class="progress-bar"><div class="progress-fill" id="progFill"></div></div>';
                    // Start polling for Spark completion
                    pollSparkStatus(data.datasetId, 0, data.message);
                } else {
                    resultDiv.className = data.success ? 'result success' : 'result error';
                    resultDiv.innerHTML = data.message || '上传失败';
                }
            })
            .catch(function(err) {
                uploadBtn.disabled = false;
                uploadBtn.textContent = '开始上传并处理';
                resultDiv.className = 'result error';
                resultDiv.innerHTML = '上传失败: ' + err.message;
            });
    });

    function pollSparkStatus(dsId, attempts, uploadMsg) {
        if (attempts > 80) { // Max 4 minutes
            resultDiv.className = 'result error';
            resultDiv.innerHTML = '⚠️ <strong>Spark 分析超时</strong><br><small>请稍后在仪表板中查看数据集 ID=' + dsId + '</small>' +
                ' <a href="index.jsp?ds=' + dsId + '">查看仪表板 →</a>';
            return;
        }
        setTimeout(function() {
            fetch('/movie-analysis/api/data?type=dataset_status&ds=' + dsId)
                .then(function(r) { return r.json(); })
                .then(function(s) {
                    if (s.status === 'ready') {
                        // Fetch summary to show counts
                        fetch('/movie-analysis/api/data?type=summary&ds=' + dsId)
                            .then(function(r) { return r.json(); })
                            .then(function(sum) {
                                var stats = sum && sum.length > 0 ? sum[0] : null;
                                var statsText = stats ?
                                    stats.total_movies + ' 电影 / ' + stats.total_ratings + ' 评分 / ' + stats.total_users + ' 用户 / 均分 ' + parseFloat(stats.avg_rating).toFixed(2) :
                                    '';
                                resultDiv.className = 'result success';
                                resultDiv.innerHTML = '<strong>🎉 分析完成！</strong>' +
                                    (statsText ? '<br><span style="font-size:18px;font-weight:bold;color:#1a237e;">' + statsText + '</span>' : '') +
                                    '<br><a href="index.jsp?ds=' + dsId + '" style="font-size:14px;">📊 查看仪表板 →</a>';
                            });
                    } else {
                        var dots = '.'.repeat((attempts % 4) + 1);
                        var pct = Math.min(attempts * 2, 90);
                        document.getElementById('progFill').style.width = pct + '%';
                        document.querySelector('#result .spinner + div strong').textContent = '⏳ Spark 正在分析数据' + dots;
                        pollSparkStatus(dsId, attempts + 1, uploadMsg);
                    }
                })
                .catch(function() {
                    pollSparkStatus(dsId, attempts + 1, uploadMsg);
                });
        }, 3000);
    }
</script>
</body>
</html>
