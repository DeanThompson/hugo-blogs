---
title: "如何高效全表扫描 Apache Phoenix 的表"
date: 2021-01-17T18:15:40+08:00
draft: false
slug: "scan-phoenix-table"
categories: ["bigdata"]
tags: ["bigdata", "database", "phoenix", "hbase"]
---

前段时间有个需求，需要从 Phoenix 里全量导出一个大表到 Hive 用于后续的查询和分析。经过一番调研和对比，最终用 Python 实现了一版直接从 HBase 并行扫描导出的程序。全表大约 230 亿行记录，同步程序峰值导出速度大约 12 万行每秒，整个同步过程历时 55 个小时。

## 数据表介绍

[Apache Phoenix](https://phoenix.apache.org/index.html) 是一个基于 Apache HBase 的 OLTP 和业务数据分析引擎，数据存储在 HBase，对外提供标准 SQL 和 JDBC API. 我们目前用 Phoenix/HBase 存储了几百 TB 的爬虫数据，日常的读写都是通过 QueryServer 调用 SQL 实现。Phoenix 支持二级索引，但我们在使用的时候出现过导致 HBase RegionServer 挂掉的情况（有可能是表太大或者使用方式不对），因此实际上基本没用二级索引

前面提到的大表是个评论内容表（后文简称 comment 表），当前的表结构大致如下：

```sql
CREATE TABLE COMMENT
(
    OBJECT_ID    BIGINT NOT NULL,     -- 评论的对象 ID，可理解为电商的商品 ID，论坛的贴子 ID 等
    COMMENT_TIME TIMESTAMP NOT NULL,  -- 评论的时间
    COMMENT_ID   BIGINT NOT NULL,     -- 本条评论记录的 ID
    UPDATE_TIME  TIMESTAMP,           -- 插入时间
    ORIGIN_DATA  VARBINARY,           -- 原始数据，是个用 snappy 压缩过的 JSON 对象
    CONSTRAINT PK PRIMARY KEY (OBJECT_ID, COMMENT_TIME, COMMENT_ID)  -- 联合主键
) DATA_BLOCK_ENCODING='FAST_DIFF', COMPRESSION = 'GZ';
```

其中 `COMMENT_ID` 是事实上的唯一主键，但由于查询条件主要是基于 `OBJECT_ID` 和 `COMMENT_TIME`，因此在建表的时候就用了 `OBJECT_ID, COMMENT_TIME, COMMENT_ID` 作为联合主键。`OBJECT_ID` 是评论对象的 ID，取值范围大，分布非常稀疏（10^6 ~ 10^12）。另外由于不同对象的热度差异也很大，从 `OBJECT_ID` 的维度看存在数据倾斜，有的 `OBJECT_ID`  可能只有几条评论，有的却几千万。`ORIGIN_DATA` 是个用 snappy 压缩过的 JSON 对象，内部包含评论的所有详情信息，其中有个属性记录了评论对象的标签（后文称 `tag`）。

<!--more-->

## 需求

原始需求是这样，要统计每个对象不同 tag 出现的次数，用 SQL 伪代码描述如下：

```sql
SELECT OBJECT_ID, year_month_day(COMMENT_TIME), ORIGIN_DATA[tag], count(1) AS freq
FROM COMMENT
GROUP BY 1, 2, 3
```

这个统计在 Phoenix 很显然无法完成，一方面是数据量太大，Phoenix 本身不适合这种 OLAP 场景；另一方面，在 Phoenix 里无法访问到 `ORIGIN_DATA` 里的 `tag` 字段。为了实现这个统计需求，并考虑到对 comment 表的查询需求较多，决定把这个表全量同步到 Hive.

Hive 上的结果表在设计上有这些考虑：

- 按照评论日期进行分区，大部分查询都会基于评论时间做过滤。
- 把 `ORIGIN_DATA`  中常用的字段（如 `tag`）解析出来，存为单独的字段，查询的时候更方便和高效。
- 把 `ORIGIN_DATA` 解压出来，保存为 `STRING` 类型，对于未解析出来的字段将来也能用 UDF 访问到。

## 同步方案对比

同步过程主要分为两个阶段：

- 从 Phoenix 读取数据，对数据做转换、解析
- 导入到 Hive

有几种很容易想到的方案。

### 1. Query Server

[Phoenix Query Server](https://phoenix.apache.org/server.html) 是一个独立的、无状态的 HTTP 服务，基于 Apache Calcite 的 Avatica 组件，对客户端提供 SQL 查询服务。客户端通过 JDBC（Java） 或 DBAPI（Python）驱动即可查询 Phoenix 的数据，跟查询 MySQL、PostgreSQL 没什么区别。我们目前有个通用的数据同步服务（Python 实现）就是从 QueryServer 查询导出实现的。

这种方式的问题是

- 由于数据倾斜，没有合适的分片方式，从而无法很好的做并行化
- 在我们的环境里，会出现查询在 10 分钟后强制超时断开连接的情况，异常信息是 `ERROR 1101 (XCL01): ResultSet is closed.` 调整 `phoenix.query.timeoutMs`（默认 10 分钟）也没用，暂时无解。由于数据倾斜，很可能出现单个扫描查询需要运行 10 分钟以上。

### 2. Hive + PhoenixStorageHandler

Phoenix 官方也提供了 [PhoenixStorageHandler](https://phoenix.apache.org/hive_storage_handler.html) 来给 Hive 读写 Phoenix. 用法比较简单，我也曾经用过这种方式来实现在两个 Phoenix 集群之间做数据同步。

但对于本文的场景并不适用，原因是

- 由于只能使用 SQL，没法实现对 `ORIGIN_DATA` 字段的解压、解析和提取
- 同样存在数据倾斜和并行化问题
- 底层只支持 MapReduce 引擎，而且 reducer 数量无法调整，只能是 1

### 3. Spark

Phoenix 官方提供了 [Spark 集成的插件](https://phoenix.apache.org/phoenix_spark.html) 可用于在 Spark 中读写 Phoenix 的数据。文档里（*Why not JDBC?* 这一节）提到，由于并行化问题这种方式没有使用 JDBC，而是用到了 Phoenix 内部的分片机制（*the phoenix-spark integration is able to leverage the underlying splits provided by Phoenix*）。考虑到 Spark 的分布式计算能力，这种方式应该是比较理想的选择。一个顾虑是，如果用单个 Spark 程序直接读取全表，可能会占用大量内存，同时对 HBase 也会有比较大压力。实践起来，可能要做一下初步划分，比如用 `OBJECT_ID` 初步将整个表尽量切分为比较均衡的若干个范围。

之前尝试使用 PySpark 操作 Phoenix，遇到很多问题没有成功。这次找同学尝试用 Scala 实现，也一直遇到各种 jar 包版本之类的问题，最终还是没能调通。

### 4. 并行扫描 HBase

上述方案中都提到数据倾斜和并行化的问题，理论上用 Spark 是比较好的选择，但由于测试失败，且没有足够时间去定位调试。于是我学习了一下 Phoenix 的文档和源代码，另辟蹊径，设计了一种高效、通用的数据导出方案：绕过了 Phoenix，直接去扫描 HBase。最终用 Python 实现了一个完整的程序。

## 思路和原理

### 并行化

通过 Phoenix 来扫描最大的问题就是数据倾斜导致不方便并行化，因此首先要解决的问题是找到一种能均匀分片的方式。[Phoenix 的 Statistics Collection 文档](https://phoenix.apache.org/update_statistics.html) 提到了 Phoenix 内部通过收集数据的统计信息来实现并行化：

> The UPDATE STATISTICS command updates the statistics collected on a table. This command collects a set of keys per region per column family that are equal byte distanced from each other. These collected keys are called *guideposts* and they act as *hints/guides* to improve the parallelization of queries on a given target region.

这些统计信息保存在 `SYSTEM.STATS` 表当中，可以通过表名查到对应的信息：

```sql
SELECT COLUMN_FAMILY, GUIDE_POST_KEY, GUIDE_POSTS_WIDTH, GUIDE_POSTS_ROW_COUNT
FROM SYSTEM.STATS
WHERE PHYSICAL_NAME = 'COMMENT'
LIMIT 5;
```

| COLUMN_FAMILY | GUIDE_POST_KEY | GUIDE_POSTS_WIDTH | GUIDE_POSTS_ROW_COUNT |
| ------------- | -------------- | ----------------- | --------------------- |
| 0             | rowkey bytes   | 314572865         | 263441                |
| 0             | rowkey bytes   | 314573187         | 251522                |
| 0             | rowkey bytes   | 314573504         | 271022                |
| 0             | rowkey bytes   | 314572810         | 256136                |

这个结果显示 Phoenix 保存了很多个 row key 的值，这些 key 之间大约间隔 300MB，26 万行，分布非常均匀。因此就可以用这些 row key 去并行扫描 HBase.

### 解码

直接扫描 HBase 得到的是一系列 KV 而不是像 Query Server 那样的结构化数据。因此新的问题是，如何从 HBase 的结果解码出结构化字段。

先来看看 HBase 的数据（有截取），可以看到有个 row key 和多个 column.

```
hbase(main):002:0> scan 'COMMENT', {LIMIT => 1}

ROW                                                                   COLUMN+CELL
 \x80\x00\x00\x00\x12\xB9\xB7G\x80\x00\x01N\xF1O\xDD\xA0\x00\x00\x00\ column=0:\x00\x00\x00\x00, timestamp=1560824973623, value=x
 x00\x80\x00\x009\xBDc\xF6\x0C
 \x80\x00\x00\x00\x12\xB9\xB7G\x80\x00\x01N\xF1O\xDD\xA0\x00\x00\x00\ column=0:\x80\x0B, timestamp=1560824973623, value=\x80\x00\x01S\x8E\x91'L\x00\x00\x00\x00
 x00\x80\x00\x009\xBDc\xF6\x0C
 \x80\x00\x00\x00\x12\xB9\xB7G\x80\x00\x01N\xF1O\xDD\xA0\x00\x00\x00\ column=0:\x80\x0C, timestamp=1560824973623
...
```

#### 1. 分析 schema

经过观察可以发现：

- row key 和值都是二进制格式，COMMENT 表的 row key 的长度都是 28 字节
- 我们只用了一个 column family，都是 0
- 每一行记录的第一个 cell 都是 key 为 `\x00\x00\x00\x00` value 为 `x` 的组合
- 每一行记录的 cell 里的 key 是有序的，都是 `\x80\x0B`,`\x80\x0C` 这种
- cell 的数量少于 Phoenix 表的 column 数量，此时 Phoenix 里可以看到部分字段是 `NULL`

通过查阅文档发现：

- `\x00\x00\x00\x00` => `x` 这个键值对是 Phoenix 有意设计的（*We’ll also add an empty key value for each row so that queries behave as expected (without requiring all columns to be projected during scans).*）

- Phoenix 的复合主键是直接将每个字段拼接在一起形成 row key，如果有变长字段（如 VARCHAR）会以一个 zero byte 结尾。（*Our composite row keys are formed by simply concatenating the values together, with a zero byte character used as a separator after a variable length type.* [见文档](https://phoenix.apache.org/faq.html)）

因此主键字段都编码到了 row key. 本文 comment 表的 `OBJECT_ID` 和 `COMMENT_ID` 都是 BIGINT，占 8 字节；`COMMENT_TIME` 是 TIMESTAMP，也是定长类型，通过推导长度为 12 字节（28 - 8 - 8）。

经过进一步观察对比 HBase 的键值对和 Phoenix 的表结构和数据发现，Phoenix 中的字段按顺序映射到 HBase，从 `\x80\x0B` 开始按 1 递增（`\x80\x0C`,`\x80\x0D`...），Phoenix 中为 `NULL` 的字段在 HBase 不会保存。

#### 2. 解码

文档有提到部分字段的编解码方式:

> For VARCHAR,CHAR, and UNSIGNED_* types, we use the HBase Bytes methods. The CHAR type expects only single-byte characters and the UNSIGNED types expect values greater than or equal to zero. For signed types(TINYINT, SMALLINT, INTEGER and BIGINT), Phoenix will flip the first bit so that negative values will sort before positive values. Because HBase sorts row keys in lexicographical order and negative value’s first bit is 1 while positive 0 so that negative value is ‘greater than’ positive value if we don’t flip the first bit. So if you stored integers by HBase native API and want to access them by Phoenix, make sure that all your data types are UNSIGNED types.

具体的编解码方式，还是需要通过看源码来弄清楚。[Phoenix Core 的 schema/types](https://github.com/apache/phoenix/tree/master/phoenix-core/src/main/java/org/apache/phoenix/schema/types) 里面有所有类型的编解码实现；如果是用 Java  或 Scala 实现数据同步可以直接调用这些类。以下举例说明几种类型的 Python 解码方式，其他类型照此思路实现即可。

* BIGINT 类型

BIGINT 的解码方法在 [PLong 类的 decodeLong 方法](https://github.com/apache/phoenix/blob/master/phoenix-core/src/main/java/org/apache/phoenix/schema/types/PLong.java#L254)。需要注意的是 Phoenix 里区分有符号和无符号两种类型，为了方便排序，有符号类型的第一个比特做了位翻转。仿照 Java 源码实现了一个 Python 版本。

```python
def decode_bigint(bs: bytes) -> int:
    """解码 BIGINT，共 8 字节，符号位做了翻转"""
    b = bs[0]
    v = b ^ 0x80
    for bb in bs[1:]:
        v = (v << 8) + (bb & 0xff)
    return v
```

- TIMESTAMP 类型

TIMESTAMP 的解码方法在 [PTimestamp 类的 toObject 方法](https://github.com/apache/phoenix/blob/master/phoenix-core/src/main/java/org/apache/phoenix/schema/types/PTimestamp.java#L134)，原理是前 8 个字节用 BIGINT（Long）类型表示毫秒数，后 4 字节用无符号 INT 类型表示纳秒数。实际中不需要到纳秒精度，所以解码的时候丢弃了。

```python
import datetime


def decode_unsigned_int(bs: bytes) -> int:
    """解码无符号 INT 类型，共 4 字节"""
    v = 0
    for bb in bs[:]:
        v = (v << 8) ^ (bb & 0xff)
    return v


def decode_timestamp(bs: bytes) -> datetime.datetime:
    """解码 TIMESTAMP 类型，共 12 个字节，前 8 字节是毫秒数，后 4 字节是纳秒；返回东八区时间"""
    mills = decode_bigint(bs[:8])
    # nanos = decode_unsigned_int(bs[8:12])
    dttm = datetime.datetime.utcfromtimestamp(mills / 1000) + datetime.timedelta(hours=8)
    return dttm
```

- VARCHAR 类型

直接用 UTF-8 解码即可：`s.decode('utf8')`.

- VARBINARY 类型

本身就是字节数组，不需要处理。

- comment 表的 row key 解码方式

```python
def decode_comment_table_row_key(key: bytes):
    object_id = decode_bigint(key[0:8])
    comment_time = decode_timestamp(key[8:20])
    comment_id = decode_bigint(key[20:28])
    return object_id, comment_time, comment_id

# decode_comment_table_row_key(b'\x80\x00\x00\x00\x12\xB9\xB7G\x80\x00\x01N\xF1O\xDD\xA0\x00\x00\x00\x00\x80\x00\x009\xBDc\xF6\x0C')
# (314160967, datetime.datetime(2015, 8, 3, 10, 7), 247990580748)
```

### 扫描

调用 happybase 连接 HBase 的 ThriftServer 进行扫描，可以参考 [happybase 的 API 文档](https://happybase.readthedocs.io/en/latest/api.html#happybase.Table.scan)。

```python
import happybase


def scan(start_key, end_key):
    conn = happybase.Connection(host='hbase1', timeout=7200)
    table = conn.table('COMMENT')
    # 注意，扫描结果不包含 end_key
    for key, row in table.scan(row_start=start_key, row_stop=end_key):
        object_id, comment_time, comment_id = decode_comment_table_row_key(key)
        # 处理其他字段...
```

## 工程化实现

上一部分基本上把底层原理和问题都解决了，剩下的就是如何实现。实际上就是常见的并行处理程序，具体细节不详细阐述，描述一下关键内容。

首先从 `SYSTEM.STATS` 表读出 comment 表所有的 row key 节点，并把相邻的 key 组装成 (start_key, end_key) 的二元组。这些二元组就是整个任务集，初始化一次即可，保存到 MySQL、Redis 或文件，给扫描程序使用。

扫描程序读取上述任务集，启动多进程（Python 的线程比较鸡肋，其他语言可以用多线程）去消费任务，扫描数据、处理、保存为文件（Hive 的 Textfile 格式或 Parquet）。启动一个后台进程，把文件上传到 HDFS 和 Hive.

一些可以注意的细节

- 为了能实现「断点续传」，可记录每个任务的状态（开始、结束时间），只处理新任务。
- 记录扫描的行数，用于统计整体进度。
- 准备多个 HBase ThriftServer，并做好负载均衡（比如客户端随机选择）
- 可在多台服务器上同时跑实现分布式，注意一下任务调度不要重复消费。一种简单的策略是对任务编号，每个节点只消费一个区间内的任务。
- 注意观察 HBase 的负载情况，适当调整并行度。本次实践中，最高的时候有 40 多个并行扫描，此时 HBase 负载稳定，其他读写程序也没有异常。在并行度上调过程中，整体的扫描性能大致是线性提升的。
