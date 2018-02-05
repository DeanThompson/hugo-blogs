+++
date = "2018-02-04T19:36:03+08:00"
title = "Redshift Snippets"
draft = false
slug = "redshift-snippets"
categories = ["devops", "sql"]
tags = ["sql", "redshift", "aws"]
+++

- 查询所有 session

```sql
SELECT * FROM stv_sessions;
```

- 终止 session

```sql
SELECT pg_terminate_backend(32281);
```

即，调用 `pg_terminate_backend` 函数，传入 process\_id。

权限：普通用户只能终止自己的 session，超级用户能终止任意 session.

- 查询正在运行的 queries

类似 MySQL 的 `SHOW PROCESSLIST`.

```sql
SELECT stv_recents.userid, stv_recents.status, stv_recents.starttime,
       stv_recents.duration, stv_recents.user_name, stv_recents.db_name,
       stv_recents.query, stv_recents.pid
FROM stv_recents
WHERE stv_recents.status = 'Running'::bpchar;
```

<!--more-->

- 创建数据库时报错：`source database "template1" is being accessed by other users`

原因：`template1` 数据库被其他 session 占用，锁住了。

解决方法：先从 `stv_sessions` 表查找 `template1` 相关的 session，然后用 `pg_terminate_backend` 杀掉。

- 备份数据到 S3

```sql
UNLOAD ('SELECT * FROM public.category') TO 's3://redshift-backup/unload/public/category/category_'
access_key_id '<access_key_id>' secret_access_key '<secret_access_key>'
DELIMITER '|' ADDQUOTES ESCAPE ALLOWOVERWRITE;
```

-  从 S3 加载数据

```sql
COPY public.category FROM 's3://redshift-backup/unload/public/category'
CREDENTIALS 'aws_access_key_id=<access_key_id>;aws_secret_access_key=<secret_access_key>'
DELIMITER '|' REMOVEQUOTES ESCAPE REGION 'cn-north-1';
```

- 定义 Python UDF

文档: [<http://docs.aws.amazon.com/redshift/latest/dg/udf-python-language-support.html>](http://docs.aws.amazon.com/redshift/latest/dg/udf-python-language-support.html)

```sql
CREATE FUNCTION f_hash(value varchar) returns varchar immutable as $$
    def sha256_hash(value):
        import hashlib, base64
        return base64.urlsafe_b64encode(hashlib.sha256(value or '').digest())
    return sha256_hash(value)
$$ language plpythonu;

SELECT address, mobile_no, f_hash(address), f_hash(mobile_no)
FROM leqi_orders LIMIT 10;
```

- 查看表所占磁盘等信息

```sql
SELECT BTRIM(pgdb.datname::character varying::text) AS "database",
       BTRIM(a.name::character varying::text) AS "table",
       (b.mbytes::numeric::numeric(18,0) / part.total::numeric::numeric(18,0) * 100::numeric::numeric(18,0))::numeric(5,2) AS pct_of_total,
       a."rows",
       b.mbytes,
       b.unsorted_mbytes
FROM stv_tbl_perm a
  JOIN pg_database pgdb ON pgdb.oid = a.db_id::oid
  JOIN (
    SELECT stv_blocklist.tbl,
           SUM(
             CASE
               WHEN stv_blocklist.unsorted = 1 OR stv_blocklist.unsorted IS NULL AND 1 IS NULL THEN 1
               ELSE 0
             END
           ) AS unsorted_mbytes,
           COUNT(*) AS mbytes
    FROM stv_blocklist
    GROUP BY stv_blocklist.tbl
  ) b ON a.id = b.tbl
  JOIN (
    SELECT SUM(stv_partitions.capacity) AS total
    FROM stv_partitions
    WHERE stv_partitions.part_begin = 0
  ) part ON 1 = 1
WHERE a.slice = 0
ORDER BY b.mbytes DESC, a.db_id, a.name;
```

查询结果样例：

```text
database  table pct_of_total  rows  mbytes  unsorted_mbytes
roma	mda_price_idx	0	50005	10	10
roma	mda_vendor	0	4	10	10
roma	mda_vendor	0	8	10	7
roma	sku_bodytype	0	9	10	7
```
