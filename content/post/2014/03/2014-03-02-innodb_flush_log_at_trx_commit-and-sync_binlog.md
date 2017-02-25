+++
date = "2014-03-02T16:16:04+08:00"
draft = false
tags = ["mysql", "innodb", "binlog"]
categories = ["mysql"]
title = "MySQL参数：innodb_flush_log_at_trx_commit 和 sync_binlog"
slug = "innodb_flush_log_at_trx_commit-and-sync_binlog"
+++

`innodb_flush_log_at_trx_commit` 和 `sync_binlog` 是 MySQL 的两个配置参数，前者是 InnoDB 引擎特有的。之所以把这两个参数放在一起讨论，是因为在实际应用中，它们的配置对于 MySQL 的性能有很大影响。

## 1. innodb_flush_log_at_trx_commit

简而言之，[`innodb_flush_log_at_trx_commit`](http://dev.MySQL.com/doc/refman/4.1/en/innodb-parameters.html#sysvar_innodb_flush_log_at_trx_commit) 参数指定了 InnoDB 在事务提交后的日志写入频率。这么说其实并不严谨，且看其不同取值的意义和表现。

1. 当 `innodb_flush_log_at_trx_commit` 取值为 `0` 的时候，log buffer 会 每秒写入到日志文件并刷写（flush）到磁盘。但每次事务提交不会有任何影响，也就是 log buffer 的刷写操作和事务提交操作没有关系。在这种情况下，MySQL性能最好，但如果 mysqld 进程崩溃，通常会导致最后 1s 的日志丢失。
2. 当取值为 `1` 时，每次事务提交时，log buffer 会被写入到日志文件并刷写到磁盘。这也是默认值。这是最安全的配置，但由于每次事务都需要进行磁盘I/O，所以也最慢。
3. 当取值为 `2` 时，每次事务提交会写入日志文件，但并不会立即刷写到磁盘，日志文件会每秒刷写一次到磁盘。这时如果 mysqld 进程崩溃，由于日志已经写入到系统缓存，所以并不会丢失数据；在操作系统崩溃的情况下，通常会导致最后 1s 的日志丢失。

上面说到的「最后 1s」并不是绝对的，有的时候会丢失更多数据。有时候由于调度的问题，每秒刷写（once-per-second flushing）并不能保证 100% 执行。对于一些数据一致性和完整性要求不高的应用，配置为 `2` 就足够了；如果为了最高性能，可以设置为 `0`。有些应用，如支付服务，对一致性和完整性要求很高，所以即使最慢，也最好设置为 `1`.

<!--more-->

## 2. sync_binlog

[sync_binlog](https://dev.MySQL.com/doc/refman/5.5/en/replication-options-binary-log.html#sysvar_sync_binlog) 是 MySQL 的二进制日志（binary log）同步到磁盘的频率。MySQL server 在 binary log 每写入 `sync_binlog` 次后，刷写到磁盘。

如果 `autocommit` 开启，每个语句都写一次 binary log，否则每次事务写一次。默认值是 `0`，不主动同步，而依赖操作系统本身不定期把文件内容 flush 到磁盘。设为 `1` 最安全，在每个语句或事务后同步一次 binary log，即使在崩溃时也最多丢失一个语句或事务的日志，但因此也最慢。

大多数情况下，对数据的一致性并没有很严格的要求，所以并不会把 `sync_binlog` 配置成 `1`. 为了追求高并发，提升性能，可以设置为 `100` 或直接用 `0`. 而和 `innodb_flush_log_at_trx_commit` 一样，对于支付服务这样的应用，还是比较推荐 `sync_binlog = 1`.

