---
title: "Impala 添加和使用 UDF"
date: 2019-10-11T14:09:28+08:00
draft: false
slug: "impala-udf"
categories: ["bigdata"]
tags: ["bigdata", "database"]
---

Impala 支持 C++ 和 Java 编写的 UDF, 把对应的 so 或 jar 文件放到 HDFS，再注册一下就能使用。官方推荐使用 C++ 编写 UDF，相比 Java 的实现有 10 倍性能提升。Hive 有丰富的函数，可以添加到 Impala 里。

- 首先在 HDFS 创建目录保存 UDF 文件，并把 Hive 的 jar 包上传进去

```
hdfs dfs -mkdir /user/hive/udfs

hdfs dfs -copyFromLocal /opt/cloudera/parcels/CDH/lib/hive/lib/hive-exec-1.1.0-cdh5.14.2.jar /user/hive/udfs/hive-builtins.jar
```

<!--more-->

- 进入 Impala 注册函数

```sql
CREATE DATABASE udfs;

CREATE FUNCTION udfs.f_get_json_object(STRING, STRING) RETURNS STRING LOCATION '/user/hive/udfs/hive-builtins.jar' SYMBOL='org.apache.hadoop.hive.ql.udf.UDFJson';

REFRESH FUNCTIONS udfs;

SHOW FUNCTIONS IN udfs;
```

- 使用

```
SELECT id,
       udfs.f_get_json_object(user_info, '$.city') AS user_city
       user_info
FROM user
LIMIT 100
```

- 删除

```
DROP FUNCTION IF EXISTS udfs.f_get_json_object(STRING, STRING)
```

## References

- [Impala User-Defined Functions (UDFs)](https://www.cloudera.com/documentation/enterprise/5-14-x/topics/impala_udf.html)
- [Hive Operators and User-Defined Functions (UDFs)](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF)
- [DROP FUNCTION Statement](https://www.cloudera.com/documentation/enterprise/5-14-x/topics/impala_drop_function.html)
- [cloudera/impala-udf-samples](https://github.com/cloudera/impala-udf-samples)
