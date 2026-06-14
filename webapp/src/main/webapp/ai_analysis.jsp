<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI 光影评鉴师 — 电影数据智能分析</title>
    <style>
        :root {
            --bg: #0f0f1a;
            --panel: #1a1a2e;
            --card: #16213e;
            --accent: #e2b04a;
            --accent2: #c49b3c;
            --text: #e0d5c1;
            --text2: #a89b8c;
            --border: #2a2a3e;
            --gold-grad: linear-gradient(135deg, #c9a84c, #e2b04a, #b8923a);
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: "Microsoft YaHei", "PingFang SC", "Noto Serif SC", serif;
            background: var(--bg);
            color: var(--text);
            height: 100vh; overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        /* ====== 顶部导航 ====== */
        .navbar {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            border-bottom: 2px solid var(--accent);
            padding: 12px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            box-shadow: 0 2px 20px rgba(226,176,74,0.15);
        }
        .navbar .brand {
            display: flex; align-items: center; gap: 12px;
        }
        .navbar .brand .icon { font-size: 32px; }
        .navbar .brand h1 {
            font-size: 20px;
            background: var(--gold-grad);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-weight: 700;
        }
        .navbar .brand .sub {
            font-size: 12px; color: var(--text2); margin-top: 2px;
        }
        .navbar .nav-links { display: flex; gap: 10px; align-items: center; }
        .navbar .nav-links a {
            color: var(--text); text-decoration: none; font-size: 15px; font-weight: 500;
            padding: 9px 18px; border-radius: 22px; transition: all .2s;
            background: rgba(226,176,74,0.08);
        }
        .navbar .nav-links a:hover { color: var(--accent); background: rgba(226,176,74,0.18); transform: translateY(-1px); }
        .navbar .nav-links a.active { color: #1a1a2e; background: var(--gold-grad); font-weight: 700; }

        /* ====== 主体布局 ====== */
        .main-container {
            display: flex; flex: 1; min-height: 0; overflow: hidden;
        }
        /* 左侧设置面板 */
        .sidebar {
            width: 300px; min-width: 300px;
            background: var(--panel); border-right: 1px solid var(--border);
            display: flex; flex-direction: column; padding: 20px 16px;
            overflow-y: auto;
        }
        .sidebar h3 {
            color: var(--accent); font-size: 14px; margin-bottom: 16px;
            display: flex; align-items: center; gap: 6px;
        }
        .sidebar h3::before { content: '⚙'; }
        .form-group { margin-bottom: 14px; }
        .form-group label {
            display: block; font-size: 12px; color: var(--text2); margin-bottom: 4px;
            font-weight: 500;
        }
        .form-group input, .form-group select {
            width: 100%; padding: 8px 12px;
            background: var(--card); border: 1px solid var(--border);
            color: var(--text); border-radius: 6px; font-size: 13px;
            outline: none; transition: border .2s;
        }
        .form-group input:focus, .form-group select:focus {
            border-color: var(--accent);
        }
        .form-group input::placeholder { color: #555; }
        .btn-save {
            width: 100%; padding: 10px;
            background: var(--gold-grad); color: #1a1a2e;
            border: none; border-radius: 6px; cursor: pointer;
            font-size: 14px; font-weight: 600; transition: all .2s;
        }
        .btn-save:hover { filter: brightness(1.1); transform: translateY(-1px); }
        .btn-save:disabled { filter: grayscale(1); cursor: not-allowed; transform: none; }

        .sidebar .divider {
            border-top: 1px solid var(--border); margin: 16px 0;
        }
        .sidebar .status {
            font-size: 12px; color: var(--text2); text-align: center;
            padding: 8px; border-radius: 4px; background: var(--card);
        }
        .sidebar .status.on { color: #4caf50; }
        .sidebar .status.off { color: #f44336; }

        /* 右侧聊天区 */
        .chat-area {
            flex: 1; min-height: 0; display: flex; flex-direction: column;
            background: var(--bg);
            position: relative; overflow: hidden;
        }
        /* 顶部数据集选择 */
        .chat-header {
            padding: 12px 24px;
            background: var(--panel); border-bottom: 1px solid var(--border);
            display: flex; align-items: center; gap: 12px;
        }
        .chat-header select {
            padding: 6px 10px; background: var(--card); border: 1px solid var(--border);
            color: var(--text); border-radius: 4px; font-size: 13px;
        }
        .chat-header .badge {
            font-size: 11px; padding: 3px 8px; border-radius: 10px;
            background: rgba(226,176,74,0.15); color: var(--accent);
        }
        /* 快捷操作 */
        .quick-actions {
            padding: 10px 24px; display: flex; gap: 8px; flex-wrap: wrap;
            border-bottom: 1px solid var(--border); background: var(--panel);
        }
        .quick-btn {
            padding: 6px 14px; font-size: 12px;
            background: var(--card); border: 1px solid var(--border);
            color: var(--text); border-radius: 16px; cursor: pointer;
            transition: all .2s; white-space: nowrap;
        }
        .quick-btn:hover { border-color: var(--accent); color: var(--accent); background: rgba(226,176,74,0.08); }

        /* 消息列表 */
        .messages {
            flex: 1; min-height: 0; overflow-y: auto; padding: 20px 24px;
            display: flex; flex-direction: column; gap: 16px;
        }
        /* 自定义滚动条 — 影院风格 */
        .messages::-webkit-scrollbar { width: 6px; }
        .messages::-webkit-scrollbar-track { background: transparent; }
        .messages::-webkit-scrollbar-thumb {
            background: #3a3a55; border-radius: 3px;
        }
        .messages::-webkit-scrollbar-thumb:hover { background: var(--accent); }
        .messages {
            scrollbar-color: #3a3a55 transparent;
            scrollbar-width: thin;
        }
        .message {
            display: flex; gap: 10px; max-width: 85%;
            animation: fadeIn .3s ease;
        }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
        .message.user { align-self: flex-end; flex-direction: row-reverse; }
        .message.assistant { align-self: flex-start; }
        .message .avatar {
            width: 36px; height: 36px; border-radius: 50%;
            display: flex; align-items: center; justify-content: center;
            font-size: 18px; flex-shrink: 0;
        }
        .message.user .avatar { background: #3949ab; }
        .message.assistant .avatar {
            background: linear-gradient(135deg, #c9a84c, #e2b04a);
        }
        .message .bubble {
            padding: 12px 16px; border-radius: 12px; font-size: 13px; line-height: 1.7;
            white-space: pre-wrap; word-break: break-word;
        }
        .message.user .bubble {
            background: #1a237e; color: #e8eaf6;
            border-bottom-right-radius: 4px;
        }
        .message.assistant .bubble {
            background: #1e1e3a; color: #d5cec0;
            border-bottom-left-radius: 4px;
            border: 1px solid #2a2a40;
        }
        .message.assistant .bubble h3 { color: var(--accent); margin: 8px 0 4px; font-size: 14px; }
        .message.assistant .bubble strong { color: #e8c547; }
        .message.assistant .bubble em { color: #c49b3c; font-style: italic; }
        .message.assistant .bubble code {
            background: rgba(226,176,74,0.1); padding: 2px 6px; border-radius: 3px;
            font-size: 12px; color: var(--accent);
        }
        .message .time { font-size: 10px; color: var(--text2); margin-top: 4px; }

        /* 打字指示器 */
        .typing { align-self: flex-start; }
        .typing .bubble {
            background: #1e1e3a; padding: 12px 16px; display: flex; gap: 6px;
        }
        .typing .dot {
            width: 7px; height: 7px; border-radius: 50%;
            background: var(--accent); animation: bounce 1.4s infinite;
        }
        .typing .dot:nth-child(2) { animation-delay: .2s; }
        .typing .dot:nth-child(3) { animation-delay: .4s; }
        @keyframes bounce {
            0%, 80%, 100% { transform: translateY(0); opacity: .4; }
            40% { transform: translateY(-8px); opacity: 1; }
        }

        /* 输入区 */
        .input-area {
            padding: 12px 24px;
            background: var(--panel); border-top: 1px solid var(--border);
            display: flex; gap: 10px;
        }
        .input-area textarea {
            flex: 1; padding: 10px 14px; min-height: 44px; max-height: 120px;
            background: var(--card); border: 1px solid var(--border);
            color: var(--text); border-radius: 8px; font-size: 13px; resize: none;
            outline: none; font-family: inherit;
        }
        .input-area textarea:focus { border-color: var(--accent); }
        .input-area textarea::placeholder { color: #555; }
        .input-area .btn-send {
            width: 44px; height: 44px; border-radius: 50%;
            background: var(--gold-grad); border: none; cursor: pointer;
            font-size: 18px; display: flex; align-items: center; justify-content: center;
            transition: all .2s; flex-shrink: 0;
        }
        .input-area .btn-send:hover { filter: brightness(1.1); transform: scale(1.05); }
        .input-area .btn-send:disabled { filter: grayscale(1); cursor: not-allowed; transform: none; }

        /* 欢迎界面 */
        .welcome {
            margin: auto; display: flex; flex-direction: column;
            align-items: center; justify-content: center; gap: 16px;
            text-align: center; padding: 40px;
        }
        .welcome .icon-big { font-size: 64px; }
        .welcome h2 {
            background: var(--gold-grad);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 24px;
        }
        .welcome p { color: var(--text2); font-size: 13px; max-width: 400px; line-height: 1.8; }

        /* 响应式 */
        @media (max-width: 768px) {
            .main-container { flex-direction: column; }
            .sidebar { width: 100%; min-width: 100%; flex-direction: row; flex-wrap: wrap; padding: 10px; }
            .sidebar h3 { display: none; }
            .sidebar .form-group { flex: 1; min-width: 120px; }
            .chat-header { padding: 8px 12px; }
        }
    </style>
</head>
<body>

<!-- ====== 导航栏 ====== -->
<nav class="navbar">
    <div class="brand">
        <span class="icon">🎬</span>
        <div>
            <h1>AI 光影评鉴师</h1>
            <div class="sub">Movie Connoisseur · Intelligent Analysis</div>
        </div>
    </div>
    <div class="nav-links">
      <a href="index.jsp">📊 仪表板</a>
      <a href="ai_analysis.jsp" class="active">🤖 AI 评鉴</a>
      <a href="upload.jsp">📤 上传</a>
      <a href="datasets.jsp">🗂️ 管理</a>
    </div>
</nav>

<!-- ====== 主体 ====== -->
<div class="main-container">
    <!-- 左侧：API 设置 -->
    <aside class="sidebar">
        <h3>AI 接口配置</h3>
        <div class="form-group">
            <label>🔑 API Key</label>
            <input type="password" id="apiKey" placeholder="sk-..." autocomplete="off">
        </div>
        <div class="form-group">
            <label>🌐 API 端点</label>
            <input type="text" id="apiEndpoint" placeholder="https://api.openai.com"
                   value="https://api.openai.com">
            <div style="font-size:10px;color:var(--text2);margin-top:3px;">
                常用: OpenAI=api.openai.com | DeepSeek=api.deepseek.com
            </div>
        </div>
        <div class="form-group">
            <label>🧠 模型</label>
            <select id="apiModel">
                <option value="gpt-4o">GPT-4o</option>
                <option value="gpt-4-turbo">GPT-4 Turbo</option>
                <option value="gpt-4">GPT-4</option>
                <option value="gpt-3.5-turbo">GPT-3.5 Turbo</option>
                <option value="deepseek-chat">DeepSeek Chat</option>
                <option value="deepseek-reasoner">DeepSeek Reasoner</option>
                <option value="claude-3-5-sonnet">Claude 3.5 Sonnet</option>
            </select>
        </div>
        <button class="btn-save" onclick="saveConfig()">💾 保存配置</button>

        <div class="divider"></div>

        <div class="status off" id="configStatus">⚫ 未配置 API Key</div>

        <div class="divider"></div>
        <div class="form-group">
            <label>📦 分析数据集</label>
            <select id="aiDataset" onchange="updateDataset()">
                <option value="0">MovieLens 1M (默认)</option>
            </select>
        </div>

        <div class="divider"></div>
        <div style="font-size:11px;color:var(--text2);line-height:1.6;">
            <p>💡 <strong>提示：</strong></p>
            <p>• 支持所有 OpenAI 兼容 API</p>
            <p>• Key 仅保存在浏览器本地</p>
            <p>• 推荐使用 GPT-4o 获得最佳分析</p>
            <p>• DeepSeek 性价比极高</p>
        </div>
    </aside>

    <!-- 右侧：对话区 -->
    <main class="chat-area">
        <div class="chat-header">
            <span>📦 当前数据集：</span>
            <select id="dsSelectorChat" onchange="switchDatasetChat(this.value)">
                <option value="0">MovieLens 1M (默认)</option>
            </select>
            <span class="badge" id="dsBadge">1000209 条评分</span>
        </div>

        <div class="quick-actions" id="quickActions">
            <button class="quick-btn" onclick="quickAsk('summary')">📋 分析数据集概况</button>
            <button class="quick-btn" onclick="quickAsk('top')">⭐ 点评热门电影</button>
            <button class="quick-btn" onclick="quickAsk('genre')">🎭 解读类别分布</button>
            <button class="quick-btn" onclick="quickAsk('users')">👥 分析用户画像</button>
            <button class="quick-btn" onclick="quickAsk('trend')">📈 评分趋势洞察</button>
            <button class="quick-btn" onclick="quickAsk('recommend')">🎯 电影推荐建议</button>
        </div>

        <!-- 消息列表 -->
        <div class="messages" id="messages">
            <div class="welcome" id="welcomeBlock">
                <div class="icon-big">🎬</div>
                <h2>光影评鉴师 · 为您服务</h2>
                <p>
                    我是一位资深的电影评鉴师，精通世界电影史与电影艺术。
                    配置 API Key 后，我可以帮您深度分析电影数据集，
                    从数据中发现电影艺术的奥秘。
                </p>
            </div>
        </div>

        <!-- 输入区 -->
        <div class="input-area">
            <textarea id="userInput" rows="1" placeholder="输入你的问题，例如：「这个数据集中评分最高的电影有哪些特点？」"
                onkeydown="if(event.key=='Enter'&&!event.shiftKey){event.preventDefault();sendMessage();}"></textarea>
            <button class="btn-send" onclick="sendMessage()" id="btnSend">➤</button>
        </div>
    </main>
</div>

<script>
// ================================
//  AI 光影评鉴师 — 前端逻辑
// ================================

var currentDs = 0;
var apiConfigured = false;

// 快捷提问模板
var quickTemplates = {
    summary:  '请以电影评鉴师的视角，全面分析这个电影数据集。从数据规模、评分分布、用户构成等角度，给出专业的数据解读和有趣的发现。',
    top:      '请点评这个数据集中评分最高的几部电影。分析它们为什么受欢迎？结合电影类型、年代背景等因素，给出专业的影评式解读。',
    genre:    '请分析这个数据集中电影类别（genre）的分布情况。哪些类型最受欢迎？不同类型电影的评分差异说明了什么？从电影艺术和观众口味的角度进行深入解读。',
    users:    '请分析这个数据集的用户画像。包括性别分布、年龄段偏好、职业差异等。不同类型的用户观影口味有何不同？有哪些有趣的发现？',
    trend:    '请基于评分数据分布，分析用户评分行为趋势。高评分和低评分电影各有什么特点？评分是否存在年代差异？给出数据驱动的电影市场洞察。',
    recommend:'基于这个数据集的分析结果，如果你要向不同类型的观众推荐电影，你会怎么推荐？请给出具体的推荐理由和观影建议。'
};

// 页面加载
document.addEventListener('DOMContentLoaded', function() {
    loadConfig();
    loadDatasets();
});

// 加载数据集列表
function loadDatasets() {
    fetch('/movie-analysis/api/data?type=datasets')
        .then(r => r.json())
        .then(function(data) {
            ['dsSelectorChat', 'aiDataset'].forEach(function(id) {
                var sel = document.getElementById(id);
                if (!sel) return;
                sel.innerHTML = '';
                data.forEach(function(d) {
                    sel.innerHTML += '<option value="' + d.id + '"' +
                        (d.id == currentDs ? ' selected' : '') + '>' +
                        d.name + '</option>';
                });
            });
            updateDsBadge();
        });
}

function switchDatasetChat(dsId) {
    currentDs = parseInt(dsId);
    document.getElementById('aiDataset').value = dsId;
    updateDsBadge();
}

function updateDataset() {
    currentDs = parseInt(document.getElementById('aiDataset').value);
    document.getElementById('dsSelectorChat').value = currentDs;
    updateDsBadge();
}

function updateDsBadge() {
    // fetch dataset summary
    fetch('/movie-analysis/api/data?type=summary&ds=' + currentDs)
        .then(r => r.json())
        .then(function(data) {
            if (data.length > 0) {
                document.getElementById('dsBadge').textContent =
                    parseInt(data[0].total_ratings).toLocaleString() + ' 条评分';
            }
        });
}

// ========== 配置管理 ==========
function saveConfig() {
    var config = {
        apiKey: document.getElementById('apiKey').value.trim(),
        endpoint: document.getElementById('apiEndpoint').value.trim(),
        model: document.getElementById('apiModel').value
    };
    if (!config.endpoint) config.endpoint = 'https://api.openai.com';
    if (!config.model) config.model = 'gpt-4o';

    localStorage.setItem('ai_config', JSON.stringify(config));
    apiConfigured = !!config.apiKey;
    updateConfigStatus();
    // 轻提示
    showToast(config.apiKey ? '✅ 配置已保存' : '⚠️ 请输入 API Key');
}

function loadConfig() {
    var saved = localStorage.getItem('ai_config');
    if (saved) {
        try {
            var config = JSON.parse(saved);
            document.getElementById('apiKey').value = config.apiKey || '';
            document.getElementById('apiEndpoint').value = config.endpoint || 'https://api.openai.com';
            document.getElementById('apiModel').value = config.model || 'gpt-4o';
            apiConfigured = !!config.apiKey;
        } catch(e) {}
    }
    updateConfigStatus();
}

function updateConfigStatus() {
    var el = document.getElementById('configStatus');
    if (apiConfigured) {
        el.textContent = '🟢 API 已配置';
        el.className = 'status on';
    } else {
        el.textContent = '⚫ 未配置 API Key';
        el.className = 'status off';
    }
}

// 轻提示
function showToast(msg) {
    var toast = document.createElement('div');
    toast.style.cssText = 'position:fixed;top:16px;left:50%;transform:translateX(-50%);' +
        'background:var(--accent);color:#1a1a2e;padding:8px 20px;border-radius:20px;' +
        'font-size:13px;font-weight:600;z-index:999;transition:opacity .3s;';
    toast.textContent = msg;
    document.body.appendChild(toast);
    setTimeout(function() { toast.style.opacity = '0'; setTimeout(function() { toast.remove(); }, 300); }, 2000);
}

// ========== 消息管理 ==========
function addMessage(role, content) {
    document.getElementById('welcomeBlock') && document.getElementById('welcomeBlock').remove();

    var div = document.createElement('div');
    div.className = 'message ' + role;
    var avatar = role === 'user' ? '👤' : '🎬';
    var time = new Date().toLocaleTimeString('zh-CN', {hour:'2-digit',minute:'2-digit'});
    div.innerHTML =
        '<div class="avatar">' + avatar + '</div>' +
        '<div><div class="bubble">' + formatContent(content) + '</div>' +
        '<div class="time">' + time + '</div></div>';
    document.getElementById('messages').appendChild(div);
    scrollBottom();
}

function addTyping() {
    var div = document.createElement('div');
    div.className = 'typing message assistant';
    div.id = 'typingIndicator';
    div.innerHTML =
        '<div class="avatar">🎬</div>' +
        '<div class="bubble"><span class="dot"></span><span class="dot"></span><span class="dot"></span></div>';
    document.getElementById('messages').appendChild(div);
    scrollBottom();
}

function removeTyping() {
    var el = document.getElementById('typingIndicator');
    el && el.remove();
}

function scrollBottom() {
    var msgs = document.getElementById('messages');
    setTimeout(function() { msgs.scrollTop = msgs.scrollHeight; }, 50);
}

// 简单的 Markdown 渲染
function formatContent(text) {
    return text
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.+?)\*/g, '<em>$1</em>')
        .replace(/### (.+)/g, '<h3>$1</h3>')
        .replace(/## (.+)/g, '<h3>$1</h3>')
        .replace(/\n/g, '<br>')
        .replace(/`([^`]+)`/g, '<code>$1</code>');
}

// ========== 发送消息 ==========
function sendMessage() {
    var input = document.getElementById('userInput');
    var text = input.value.trim();
    if (!text) return;

    if (!apiConfigured) {
        showToast('⚠️ 请先在左侧配置 API Key');
        return;
    }

    input.value = '';
    input.style.height = 'auto';
    addMessage('user', text);
    addTyping();

    var config = JSON.parse(localStorage.getItem('ai_config') || '{}');

    var payload = {
        apiKey: config.apiKey,
        endpoint: config.endpoint || 'https://api.openai.com',
        model: config.model || 'gpt-4o',
        datasetId: '' + currentDs,
        messages: [
            { role: 'user', content: text }
        ]
    };

    fetch('/movie-analysis/api/ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json;charset=UTF-8' },
        body: JSON.stringify(payload)
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
        removeTyping();
        if (data.error) {
            addMessage('assistant', '❌ **出错了**：' + data.error + '\n\n请检查 API Key 和网络连接。');
        } else if (data.choices && data.choices[0]) {
            addMessage('assistant', data.choices[0].message.content);
        } else {
            addMessage('assistant', '⚠️ 收到了未知格式的响应，请检查 API 配置。');
        }
    })
    .catch(function(err) {
        removeTyping();
        addMessage('assistant', '❌ **请求失败**：' + err.message + '\n\n可能原因：\n- API 端点不可达\n- 网络连接问题\n- API Key 无效');
    });
}

// ========== 快捷操作 ==========
function quickAsk(type) {
    var text = quickTemplates[type];
    if (text) {
        document.getElementById('userInput').value = text;
        sendMessage();
    }
}

// ========== 自动调整输入框高度 ==========
document.getElementById('userInput').addEventListener('input', function() {
    this.style.height = 'auto';
    this.style.height = Math.min(this.scrollHeight, 120) + 'px';
});

</script>
</body>
</html>
