# 电影评分大数据分析系统

MovieLens 1M + 自定义电影数据集 -> Hadoop HDFS -> Hive/Spark 分析 -> MySQL -> JSP + ECharts 可视化 + AI 智能评鉴

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 数据存储 | Hadoop HDFS 2.7.1 / MySQL 5.7 |
| 大数据分析 | Hive 2.1.0 / Spark 2.1.0 (PySpark) |
| Web 后端 | Java Servlet (Tomcat 7) + JDBC |
| Web 前端 | JSP + ECharts 5.4.3 + Fetch API |
| AI 分析 | OpenAI 兼容 API (DeepSeek/GPT-4o) |
| 虚拟化 | VMware (Ubuntu 16.04, NAT) |

## 快速开始

### 环境
- **Windows**: Java 21 + Maven 3.9 + Python 3.14 + SSH
- **VM**: Hadoop 2.7.1 + Hive 2.1.0 + Spark 2.1.0 + MySQL 5.7
- **VM IP**: 192.168.11.130 (VMware NAT)

### 启动
```bash
# 1. VM内启动 MySQL
sudo service mysql restart

# 2. Windows启动 Web
cd webapp && mvn tomcat7:run

# 3. 浏览器访问
# http://localhost:8080/movie-analysis/          仪表板
# http://localhost:8080/movie-analysis/ai_analysis.jsp  AI评鉴
# http://localhost:8080/movie-analysis/upload.jsp       上传
# http://localhost:8080/movie-analysis/datasets.jsp     管理
```

## 核心功能

### 仪表板 (7张ECharts图表)
评分分布/热门电影TOP20/类别玫瑰饼图/男女对比/年龄段/职业统计/活跃用户TOP20
支持多数据集切换 (?ds=N)，动态坐标范围，含dataZoom滑块缩放

### 自定义数据集上传
- 支持 CSV/TSV/:: 分隔，自动列名映射(user/userId->user_id等)
- 双层分析: CsvImporter(SQL快速) + PySpark(深度)
- 实时反馈: 上传页每3秒轮询Spark状态(旋转spinner+进度条+完成统计)
- SCP到VM隔离子目录 custom/ds{N}/

### 坏数据容错
空文件/无效分隔符/无效列名->立即拒绝
重复表头->自动跳过+SCP前清洗
无效评分(<0或>10或非数字)->Spark过滤

### AI光影评鉴师
支持OpenAI/DeepSeek/Claude等兼容API，自填Key(浏览器localStorage)
自动注入数据集上下文，6个快捷分析按钮，后端Java Servlet代理

### 数据集管理
独立管理页(datasets.jsp)，查看/删除所有数据集
删除时DROP全部ds{N}_*表+清理VM文件，默认数据集保护

## 项目结构
```
movie_bigdata_analysis/
├── data/                 测试数据+坏数据样本
├── scripts/              preprocess.py, spark_custom_analysis.py
├── hive/                 Hive DDL+分析SQL
├── output/               MySQL schema, Sqoop脚本
├── webapp/               Maven Web项目
│   └── src/main/
│       ├── java/.../dao/     DatabaseConnector, CsvImporter
│       └── java/.../servlet/ DataServlet, UploadServlet, AiAnalysisServlet
│       └── webapp/           index.jsp, upload.jsp, datasets.jsp, ai_analysis.jsp
└── docker-compose.yml    Docker备用方案
```

## API端点
| 端点 | 说明 |
|------|------|
| GET /api/data?type=summary&ds=N | 仪表板汇总 |
| GET /api/data?type=rating_dist&ds=N | 评分分布 |
| GET /api/data?type=top_movies&ds=N | 热门电影 |
| GET /api/data?type=genre_stats&ds=N | 类别统计 |
| GET /api/data?type=active_users&ds=N | 活跃用户 |
| GET /api/data?type=gender_comp&ds=N | 性别对比 |
| GET /api/data?type=age_stats&ds=N | 年龄段 |
| GET /api/data?type=occupation_stats&ds=N | 职业统计 |
| GET /api/data?type=datasets | 数据集列表 |
| GET /api/data?type=dataset_status&ds=N | Spark状态 |
| GET /api/data?type=delete_dataset&ds=N | 删除数据集 |
| POST /api/ai | AI代理 |
| POST /upload | 上传数据集 |

## GitHub
```bash
git remote add movie_bigdata_analysis git@github.com:Shadow8412/movie_bigdata_analysis.git
git push movie_bigdata_analysis version4
```
