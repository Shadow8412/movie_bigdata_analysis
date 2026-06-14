# 基于 Hive + Spark 的电影评分大数据分析系统

MovieLens 100万级电影评分数据 → Hadoop HDFS → Hive/Spark分析 → Sqoop → MySQL → JSP+ECharts可视化

## 快速测试（Ubuntu，3步骤）

```bash
# 1. 安装依赖
sudo apt install -y python3 openjdk-8-jdk maven docker.io docker-compose-v2 wget unzip && sudo systemctl enable --now docker
sudo usermod -aG docker $USER && newgrp docker

# 2. 一键全流程测试
cd ~/movie_bigdata_analysis
bash test.sh

# 3. 浏览器查看
#   仪表板:  http://localhost:8080/movie-analysis
#   HDFS:    http://localhost:50070
```

## Docker 镜像拉取超时？（Ubuntu 网络不好时用这招）

**在 Windows 上拉镜像 → 导出 → 传到虚拟机加载：**

```bat
:: Windows 上双击运行（需装 Docker Desktop）
export_images.bat
```

把生成的 `images_export` 文件夹传到 Ubuntu 虚拟机，然后：

```bash
# Ubuntu 上加载镜像
cd ~/movie_bigdata_analysis
bash load_images.sh

# 然后正常测试
bash test.sh
```

## 分步测试

```bash
bash test.sh                    # 全流程（预处理 → Docker启动 → Hive → MySQL）
bash test.sh --preprocess       # 仅数据预处理（不依赖Docker，纯Python）
bash test.sh --docker           # 仅启动Docker环境
bash test.sh --hive             # 仅Hive分析查询
bash test.sh --mysql            # 仅测试MySQL连接
bash test.sh --web              # 启动Web可视化（mvn tomcat7:run）
bash test.sh --clean            # 清理全部环境
```

## 能在Windows上测什么

| 模块 | Windows能测? | 方式 |
|------|:---:|------|
| `scripts/preprocess.py` | 能 | `python preprocess.py` 直接跑 |
| `webapp/` JSP+ECharts | 能 | IDEA 打开 → Tomcat 运行 → 临时连MySQL即可 |
| `output/mysql_schema.sql` | 能 | 装个 Windows 版 MySQL |
| HDFS / Hive / Sqoop | 不能 | 必须 Linux（或用 Docker） |

## 项目结构

```
movie_bigdata_analysis/
├── test.sh                     # ★ 一键测试脚本
├── docker-compose.yml          # Docker环境（HDFS+Hive+MySQL）
├── docker/hadoop.env           # Hadoop配置
├── data/download.sh            # 数据集下载
├── scripts/
│   ├── preprocess.py           # Python预处理
│   ├── run_all.sh              # 传统方式全流程
│   ├── check_env.sh            # 环境检查
│   ├── spark_analysis.py       # ★ Spark DataFrame 分析
│   └── run_spark.sh            # ★ Spark 一键执行
├── hive/
│   ├── 01_create_tables.sql    # Hive DDL（4张外部表→4张ORC内部表）
│   └── 02_analysis_queries.sql # 7大类HiveQL分析
├── output/
│   ├── mysql_schema.sql        # MySQL 7张结果表
│   └── sqoop_export.sh         # Hive→MySQL导出
├── webapp/                     # Maven Web项目
│   └── src/main/
│       ├── java/.../dao/DatabaseConnector.java
│       ├── java/.../servlet/DataServlet.java
│       └── webapp/index.jsp    # 7张ECharts图表仪表板
│       ├── upload.jsp                   # ★ 自定义数据集上传
│       └── java/.../servlet/UploadServlet.java  # ★ 上传处理
│       └── java/.../dao/CsvImporter.java        # ★ CSV自动解析
└── report/分工说明.md          # 五人分工明细
```

## 功能-代码映射表

### 数据预处理

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 下载数据集 | `data/download.sh` | wget 下载 MovieLens 1M zip → unzip 解压 |
| 格式转换 (:: → CSV) | `scripts/preprocess.py` L14-44 | Python `split("::")` 分隔符转换 |
| Genres 拆分 (Action\|Comedy → 多行) | `scripts/preprocess.py` L50-54 | `split("|")` 一对多展开 |
| 年龄分组 (数值 → 标签) | `scripts/preprocess.py` L107-113 | `age_group()` 函数：1→Under18, 25→19-25... |
| 职业映射 (编码 → 名称) | `scripts/preprocess.py` L116-123 | `occupation_map` 字典：0→other, 1→academic... |
| 数据校验 (类型/范围) | `scripts/preprocess.py` L84-90 | try/except + 1≤rating≤5 范围检查 |

### 大数据分析 (Hive 方案)

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| HDFS 目录创建 | `scripts/run_all.sh` L31-35 | `hdfs dfs -mkdir -p` 创建 4 个目录 |
| 数据上传到 HDFS | `scripts/run_all.sh` L37-41 | `hdfs dfs -put -f` 上传 CSV |
| Hive DDL 建表 | `hive/01_create_tables.sql` L1-73 | 4 张外部表 (TEXTFILE) → 4 张内部表 (ORC) |
| 评分分布统计 | `hive/02_analysis_queries.sql` L10-15 | `GROUP BY CAST(rating AS INT)` + 窗口函数算百分比 |
| TOP20 电影 | `hive/02_analysis_queries.sql` L20-28 | 多表 JOIN + `HAVING COUNT>=50` + `ORDER BY avg DESC LIMIT 20` |
| 电影类别统计 | `hive/02_analysis_queries.sql` L33-40 | JOIN movie_genres + GROUP BY genre |
| 活跃用户 TOP20 | `hive/02_analysis_queries.sql` L45-53 | JOIN users + ORDER BY COUNT DESC |
| 男女评分对比 | `hive/02_analysis_queries.sql` L58-67 | GROUP BY gender + CASE WHEN 计算好评率 |
| 年龄段偏好 | `hive/02_analysis_queries.sql` L72-85 | GROUP BY age_group + ROW_NUMBER OVER PARTITION |
| 职业评分习惯 | `hive/02_analysis_queries.sql` L90-100 | GROUP BY occupation + 人均评分计算 |

### 大数据分析 (Spark 方案) — 替代 Hive MapReduce

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 读取 HDFS CSV | `scripts/spark_analysis.py` L33-55 | `spark.read.option("header","true").csv()` 4 个 DataFrame |
| 内存缓存 | `scripts/spark_analysis.py` L58 | `ratings.cache()` 4 个 DataFrame 缓存加速 |
| 评分分布 | `scripts/spark_analysis.py` L86-93 | `groupBy + agg(count) + withColumn(percentage)` |
| TOP20 电影 | `scripts/spark_analysis.py` L99-105 | `join + groupBy + agg(avg) + filter(>=50) + orderBy(desc) + limit(20)` |
| 电影类别统计 | `scripts/spark_analysis.py` L111-120 | 两次 groupBy(genre) → JOIN → select 别名列 |
| 活跃用户 TOP20 | `scripts/spark_analysis.py` L126-131 | join + groupBy(用户属性) + orderBy(desc) + limit(20) |
| 男女评分对比 | `scripts/spark_analysis.py` L137-148 | 两次 groupBy(gender) → JOIN → withColumn(好评率) |
| 年龄段分析 | `scripts/spark_analysis.py` L154-159 | groupBy(age_group) + agg + join |
| 职业评分习惯 | `scripts/spark_analysis.py` L165-175 | groupBy(occupation) + agg + withColumn(人均) |
| 写入 MySQL | `scripts/spark_analysis.py` L68-76 | `df.write.jdbc()` 8 次调用 |
| 一键执行脚本 | `scripts/run_spark.sh` | spark-submit + JDBC jar 依赖 |

### 数据存储

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| MySQL 表结构 | `output/mysql_schema.sql` | 7 张结果表 + 1 张汇总表 DDL |
| 汇总表 | `output/summary_table.sql` | dashboard_summary: 电影/评分/用户总数 + 均分 |
| Hive→MySQL (传统) | `output/sqoop_export.sh` | Sqoop export 命令 (Docker 方案用) |

### Web 可视化

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 数据库连接池 | `webapp/.../dao/DatabaseConnector.java` | JDBC 单例模式，`queryToJson()` 通用查询转 JSON |
| RESTful API 路由 | `webapp/.../servlet/DataServlet.java` L40-99 | `switch(type)` 分发 8 个端点，调用 queryToJson |
| 前端仪表板布局 | `webapp/.../webapp/index.jsp` L1-65 | CSS Grid 响应式布局，4 卡片 + 7 图表面板 |
| 评分分布柱状图 | `index.jsp` L140-160 | ECharts bar + LinearGradient + markLine(平均值) |
| TOP20 水平条形图 | `index.jsp` L165-185 | ECharts bar (横向) + 右侧数值标签 |
| 类别玫瑰饼图 | `index.jsp` L190-205 | ECharts pie + roseType:area |
| 男女对比组合图 | `index.jsp` L210-235 | 双柱 + 双线 + 双Y轴 |
| 年龄段组合图 | `index.jsp` L240-265 | 双柱 + 折线 (symbolSize: 10) |
| 职业分析组合图 | `index.jsp` L270-295 | 柱状 + 折线 (symbol: diamond) + x轴旋转45° |
| 活跃用户条形图 | `index.jsp` L300-330 | 彩色条形图 + dataZoom 滑块缩放 |

### Docker 容器化 (传统方案)

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 服务编排 | `docker-compose.yml` | 6 容器: NameNode, DataNode, MetastoreDB, Metastore, HiveServer2, MySQL |
| Hadoop 配置 | `docker/hadoop.env` | CLUSTER_NAME, CORE_CONF 等环境变量 |
| Windows 镜像导出 | `export_images.bat` | docker save → tar 打包 |
| Linux 镜像加载 | `load_images.sh` | docker load < tar |

### 一键测试

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 全流程测试 | `test.sh` | Bash: 预处理→Docker→Hive→MySQL→Web，支持分步参数 |
| 环境检查 | `scripts/check_env.sh` | 检查 Python/Java/Hadoop/Hive/Docker 是否安装 |

### 自定义数据集上传

| 功能 | 代码位置 | 实现方式 |
|------|---------|---------|
| 上传页面 (拖拽) | `webapp/.../upload.jsp` | HTML5 Drag & Drop + Fetch API 异步上传 |
| 文件接收 + SCP | `webapp/.../servlet/UploadServlet.java` | `@MultipartConfig` 接收 → SCP 到 VM → SSH 触发 Spark |
| 分隔符检测 | `scripts/spark_custom_analysis.py` L28-33 | 统计首行 `::` `\t` `,` 出现次数 |
| 列名自动映射 | `spark_custom_analysis.py` L35-56 | movieId→movie_id, score→rating 等 |
| 文件类型分类 | `spark_custom_analysis.py` L58-86 | 按列名组合自动分类 movies/ratings/users |
| Spark 批量分析 | `spark_custom_analysis.py` L90-190 | DataFrame API: groupBy → agg → join → JDBC write |
| 仪表板自动切换 | `DataServlet.java` (custom 分支) | 检测 ratings_custom 有数据 → 实时 SQL 查询 |

### 大数据分析 (Spark 自定义数据集) — 处理任意电影数据

| 分析项 | 代码位置 | Spark 实现 |
|--------|---------|-----------|
| 评分分布 | `spark_custom_analysis.py` L95-100 | `groupBy("score").agg(count)` |
| TOP20 电影 | `spark_custom_analysis.py` L103-110 | `join + groupBy + agg + filter + orderBy + limit` |
| 类别统计 | `spark_custom_analysis.py` L113-125 | `split + explode + groupBy + join` |
| 活跃用户 | `spark_custom_analysis.py` L128-140 | `groupBy(复合列) + orderBy + limit` |
| 性别对比 | `spark_custom_analysis.py` L143-151 | 双 groupBy → JOIN → withColumn 好评率 |
| 年龄段 | `spark_custom_analysis.py` L154-165 | `when().when().otherwise()` 动态分段 |
| 职业统计 | `spark_custom_analysis.py` L168-176 | `groupBy + agg + withColumn 人均` |

## Hive分析查询（7大类）

| # | 分析内容 | 关键SQL |
|---|---------|--------|
| 1 | 评分整体分布 | `GROUP BY rating` |
| 2 | 评分最高TOP20电影 | 多表JOIN + `HAVING COUNT>=50` |
| 3 | 电影类别统计 | 拆分Genres表 + `GROUP BY genre` |
| 4 | 最活跃用户TOP20 | `ORDER BY COUNT DESC` |
| 5 | 男女用户评分对比 | `GROUP BY gender` + CASE WHEN计算好评率 |
| 6 | 不同年龄段偏好 | 6个年龄段 + `ROW_NUMBER OVER PARTITION` |
| 7 | 各职业评分习惯 | 21种职业统计，人均评分数 |

## Spark 分析（替代 Hive MapReduce）

项目支持使用 **Apache Spark 2.1** 替代 Hive MapReduce 完成数据分析。
Spark 直接从 HDFS 读取 CSV，使用 **DataFrame API + Spark SQL** 进行 7 大类聚合分析，JDBC 写入 MySQL。

### 运行方式

```bash
# 在虚拟机上执行
cd ~/movie_bigdata_analysis/scripts
bash run_spark.sh
```

或手动提交：

```bash
/usr/local/spark/bin/spark-submit \
    --master local[4] \
    --jars /usr/local/spark/jars/mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar \
    scripts/spark_analysis.py
```

### 分析流程

```
HDFS CSV (raw_movies/raw_ratings/raw_users/raw_genres)
    ↓  Spark DataFrameReader
DataFrame (movies, ratings, users, genres)
    ↓  groupBy / agg / join / filter / orderBy
7 类分析结果 DataFrame
    ↓  JDBC write
MySQL (movie_analysis 数据库)
    ↓
JSP + ECharts 仪表板
```

### Hive vs Spark 对比

| 对比项 | Hive on MR | Spark |
|--------|:---:|:---:|
| 执行引擎 | MapReduce | Spark Core |
| 编程接口 | HiveQL | DataFrame API + SQL |
| 中间结果 | 写 HDFS | 内存缓存 |
| 速度 | 分钟级 | 秒级 |
| 适用场景 | 批处理 | 迭代/交互式分析 |

## Docker 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| HDFS NameNode Web UI | 50070 | 文件系统浏览 |
| HiveServer2 | 10000 | Beeline连接 |
| MySQL | 3306 | root/root |
| Web可视化 | 8080 | 仪表板主页 |

## 演示启动指南（Windows + 虚拟机）

适用场景：Windows VS Code 开发，通过 SSH 连接 Linux 虚拟机（已预装 Hadoop/Hive/MySQL）。

### 第一步：启动虚拟机并确认环境

```powershell
# 在 VMware/VirtualBox 中启动虚拟机，确认 IP（假设为 10.0.0.201）
# SSH 已配置免密登录，直接连接：
ssh my-hadoop

# 在虚拟机里确认服务已启动：
jps                        # 应有 NameNode, DataNode, ResourceManager 等 6 个进程
systemctl status mysql     # MySQL 应显示 active (running)
```

> 若 `jps` 缺少 NameNode/DataNode，在虚拟机里执行：
> ```bash
> /usr/local/hadoop/sbin/start-all.sh
> ```

### 第二步：启动 Web 可视化

在 VS Code 终端（PowerShell）中执行：

```powershell
mvn -f d:\code\Bigdata\webapp\pom.xml org.apache.tomcat.maven:tomcat7-maven-plugin:2.2:run
```

看到 `Starting ProtocolHandler ["http-bio-8080"]` 后，浏览器打开：

> 🌐 **http://localhost:8080/movie-analysis**

### 故障排查

| 现象 | 解决方法 |
|------|----------|
| 连接虚拟机超时 | 检查虚拟机 IP 是否为 `10.0.0.201`，`ssh my-hadoop` 测试 |
| 仪表板数据全为 `-` | 确认虚拟机 MySQL 正在运行 (`systemctl status mysql`) |
| Tomcat 端口 8080 被占用 | `Stop-Process -Name "java" -Force` 后重试 |
| Maven 编译失败 | 先执行 `mvn -f d:\code\Bigdata\webapp\pom.xml clean package -DskipTests` |

### 核心信息速查

| 项目 | 值 |
|------|-----|
| 虚拟机 IP | `10.0.0.201` |
| SSH 别名 | `ssh my-hadoop`（已配免密） |
| MySQL 用户 | `movieapp` / `movieapp123` |
| 仪表板 | `http://localhost:8080/movie-analysis` |
| HDFS UI | `http://10.0.0.201:50070` |
