---
title: "聊聊幂等"
slug: "idempotence"
date: 2019-03-17T23:38:00+08:00
draft: false
categories: ["devops"]
tags: ["HTTP", "ETL"]
---

计算机领域有很多概念都来自数学，今天要讨论的幂等性就是其中之一。在程序世界，幂等的意义是对于某个操作，执行一次和多次所产生的影响应该相同。比如赋值操作是幂等的，`a = 1` 无论运行多少次，最终的影响都是一样；而计数则不是。幂等在很多系统中都很重要，结合自己的经历，聊聊 HTTP 的幂等性和 ETL 场景里的幂等。

## HTTP 的幂等性

[HTTP RFC 规范](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html)里有关于幂等方法的讨论：

> Methods can also have the property of "idempotence" in that (aside from error or expiration issues) the side-effects of N > 0 identical requests is the same as for a single request. The methods GET, HEAD, PUT and DELETE share this property. Also, the methods OPTIONS and TRACE SHOULD NOT have side effects, and so are inherently idempotent.

<!--more-->

Restful 风格的 API 比较忠实的遵守了 HTTP 协议的各种规定，充分利用了 HTTP 方法和状态码的语义，用 URI 表示资源，`POST`, `DELETE`, `PUT` 和 `GET` 来对应增删改查四种操作。这些方法里，除了 `POST`，其它三个都是幂等的，我们分别从语义和实现的角度来讨论。

- `GET` 方法用于获取资源，可以获取一个（`GET /posts/1`）或多个（`GET /posts`）。在服务端实现上，其实就是根据资源标识（主键或全表）查询对应的数据。这个操作没有副作用，虽然可能会每次得到不同的结果，不管执行多少次，都不会对数据库的数据产生影响。

- `DELETE` 用于删除资源，`DELETE /posts/1` 会触发服务端从数据库删除主键为 `1` 的记录，调用一次和 N 次产生的副作用都是一致的。

- `POST` 用于创建资源，服务器获取数据后会在数据库里新增一条记录，得到一个新的主键。在正常情况下，服务器不会预先检查数据是否存在，所有每次相同的请求都会导致新建一份资源（除非有唯一性约束）。因此 `POST` 不具备幂等性，设计 API 时需要仔细考虑如何避免产生重复数据。

- `PUT` 通常用于更新资源，但实际上也可以创建，在 HTTP 规范里，`PUT` 类似有些数据库里的 `UPSERT`，即如果数据存在就更新，否则新建。两种场景的区别在于，资源标识是谁生成的。更新的场景一般是先从服务端获取了数据，客户端修改后提交更新；另一种场景则是客户端指定，如博客系统里 slug 是唯一的，而且通常由作者指定。不管是更新还是创建，由于存在主键或唯一性约束，执行多次都不会产生额外的副作用。

实现幂等性非常重要。在理想的世界里，所有的操作都能一次性成功；然而现实情况往往很复杂，网络波动可能导致请求失败，用户（客户端）可能会无意的触发多次重复请求。为了确保成功率，在失败时通常都会有重试机制，如果系统没有实现幂等，可能会产生难以预料的结果。在网上搜索幂等经常能看到支付、转账、取款的例子（这些例子也经常用于数据库事务），解决方案也类似，一般用 token (ticket) + 唯一性约束来实现。

## ETL 与幂等

上文讨论 HTTP 幂等性时提到了很多关于数据库的操作，其中最重要就是数据去重，数据库层面一般由主键或唯一性约束来保证。在做 ETL 任务时，幂等也非常重要。

一个常见的 ETL 场景是从生产系统（MySQL）把数据增量同步到 Hive，然后在 Hive 里对数据做处理后增量写到另一个表。全量更新比较容易，增量更新就一定要确保幂等，否则重试就会产生重复数据。ETL 任务不仅在失败的时候需要重跑，即使成功了也有可能会调整业务逻辑然后重新运行。所有 ETL 任务都应该实现幂等，即使是一次性的。

Hive 里没有主键和唯一性约束的概念，所以需要想办法实现去重。其中一种思路是用分区表，每次增量更新都覆盖一个分区。但也有的数据并不适合做分区，比如商品信息表。虽然 Hive 没有主键和唯一性约束，但如果数据本身存在可以表示唯一记录的字段（多个也行），可以考虑使用 `FULL JOIN` 或 `LEFT JOIN` 的方式来实现。首先把新增数据保存到一个 staging 表，然后更新到 target 表。

- 使用 `FULL JOIN`

```sql
-- 两表合并，同时出现的记录优先取 staging 表的值，最终的影响是已存在则更新，否则插入

INSERT OVERWRITE TABLE target
SELECT COALESCE(a.id, b.id),
       COALESCE(a.name, b.name)
FROM staging a FULL JOIN target b ON a.id = b.id
```

- 使用 `LEFT JOIN`

```sql
-- 找出仅在 target 表存在的记录，再加上 staging 的所有记录，最终的影响也是已存在则更新，否则插入

INSERT OVERWRITE TABLE target
SELECT a.id, a.name
FROM target a LEFT JOIN staging b ON a.id = b.id
WHERE b.id IS NULL

UNION ALL

SELECT * FROM staging
```

这其实就是一种 MERGE 操作，两种方式都实现了幂等。有时候 staging 的数据是完全新增的，也不能使用 `INSERT INTO`，因为多次执行会导致数据重复。这种技术不仅适用于 Hive，MySQL, PostgeSQL 这些数据库有主键和唯一性约束，但用 `JOIN` 的方式往往会更高效简单。

## 参考

- [理解HTTP幂等性](https://www.cnblogs.com/weidagang2046/archive/2011/06/04/idempotence.html)
- [RFC 2616, Hypertext Transfer Protocol -- HTTP/1.1, Method Definitions](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html)
- [ETL Best Practices with airflow - ETL Principles](https://gtoonstra.github.io/etl-with-airflow/principles.html?highlight=idempotency)
- [每个工程师都应该了解的：聊聊幂等](https://time.geekbang.org/column/article/896)

