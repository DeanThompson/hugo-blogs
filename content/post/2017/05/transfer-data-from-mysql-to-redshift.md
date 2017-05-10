+++
date = "2017-05-10T17:36:29+08:00"
draft = false
tags = ["aws", "redshift"]
categories = ["aws"]
title = "MySQL 数据导入到 Redshift"
slug = "transfer-data-from-mysql-to-redshift"
+++

## 设计表

首先是设计表结构。建表语法差别不大，有一些地方可以注意一下：

- Redshift 貌似没有无符号类型，所以要把 unsigned 类型的字段修改成相应的 INT 或 BIGINT 类型。
- FLOAT 类型改成 REAL 或 FLOAT4
- 把索引语句去掉，保留主键、外键、唯一性约束，Redshift 不会检查这些约束，但是查询时会用于优化。
- Redshift 的 CHAR 类型只能包含单字节 ASCII 字符，对于非 ASCII 数据需要把 CHAR 改成 VARCHAR 类型
- 有可能 MySQL 中存的是 unicode，而 Redshift 中存的是 bytes，所以 VARCHAR 的长度也要调整，避免溢出。最简单的，可以用 MySQL 的字段长度 * 3.

关于 sort key, dist key 等设计，只属于 Redshift 范畴，参考官网文档即可。

<!--more-->

## 加载数据

因为 Redshift 推荐使用 `COPY` 命令从 S3 加载数据，所以首先得要从 MySQL 中导出数据，然后上传到 CSV.

以导出 CSV 为例，需要注意使用 `"` 符号作为转义字符，而不是 `\`. 另外最好用 `"` 把每个值都 wrap 起来，免得有些多行字符串导致出错。导出后可以压缩成 gzip 格式，在上传 S3 的时候可以快一些。

Redshift 的 `COPY` 例子：

```sql
COPY syns_bigdata
FROM 's3://some-bucket/some_filename.csv.gz'
credentials 'aws_access_key_id=<aws_access_key_id>;aws_secret_access_key=<aws_secret_access_key>'
region 'cn-north-1' CSV GZIP NULL AS 'NULL';
```

语法很简单，需要注意的有：

- `aws_access_key_id` 和 `aws_secret_access_key` 要有访问 S3 的权限
- 指定 region
- 指定文件格式，`CSV GZIP` 表示是 gzip 压缩的 CSV 文件
- 可以用 `NULL AS` 语句指定 NULL 值
