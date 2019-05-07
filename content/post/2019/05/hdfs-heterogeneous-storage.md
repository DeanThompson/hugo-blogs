---
title: "HDFS 异构存储调研"
date: 2019-05-07T15:47:04+08:00
draft: false
slug: "hdfs-heterogeneous-storage"
categories: ["bigdata"]
tags: ["bigdata","hdfs", "hadoop"]
---

## 结论

- HDFS 支持配置多个数据目录，同一节点默认按照 Round Robin 策略写入。硬盘不做 RAID，每块盘单独挂载。
- HDFS 支持异构存储，即不同的存储类型和存储策略，可用于实现冷热分级，从而降低成本

## 存储类型

按访问速度降序：

- RAM_DISK: 即内存
- SSD: SSD，OLTP 类场景（如 HBase）可以考虑使用
- DISK: 普通硬盘
- ARCHIVE: 归档存储，可使用廉价、高容量存储（甚至单机超百 T）

<!--more-->

## 存储策略

共有 6 种策略

- **Hot**: 即通常意义的热数据，需要经常使用。所有副本都存在 DISK. **这是默认的策略。**
- **Cold**: 即通常意义的冷数据，很少使用，主要是归档备份。所有副本都存在 ARCHIVE.
- **Warm**: 介于冷热之间。一个副本放 DISK，其余的放 ARCHIVE.
- **All_SSD**: 所有副本都在 SSD.
- **One_SSD**: 一个副本在 SSD，其余的放 DISK.
- **Lazy_Persist**: 适用于单副本数据，放在内存。先写到 RAM_DISK, 再持久化到 DISK.

按访问速度从快到慢排列

策略 | 块分布 | creationFallbacks | replicationFallbacks
----|----|----|----
`Lazy_Persist` | RAM_DISK: 1, DISK: n-1 | DISK | DISK
`All_SSD` | SSD: n | DISK | DISK
`One_SSD` | SSD: 1, DISK: n-1 | SSD, DISK | SSD, DISK
`Hot` | DISK: n | < none > | ARCHIVE
`Warm` | DISK: 1, ARCHIVE: n-1 | ARCHIVE, DISK | ARCHIVE, DISK
`Cold` | ARCHIVE: n | < none > | < none >

> 注：creationFallbacks 是对于第一个创建的 block 的 fallback 情况时的可选存储类型；replicationFallbacks 是 block 的其余副本的 fallback 情况时的可选存储类型

## 配置

每个磁盘单独挂载到不同目录，需要注意加上 `noatime` 选项。 首先配置 DataNode 的数据目录

- `dfs.storage.policy.enabled`: 设置为 `true`，默认是 `true`.
- `dfs.datanode.data.dir`: 可配置多个路径，用 `,` 分隔，每个路径加上存储类型标签作为前缀，如
  
```
[SSD]file:///dfs/dn1,[DISK]file:///dfs/dn2,[ARCHIVE]file:///dfs/dn3
```

> 注: 通过 Cloudera Manager 配置不需要写 `file://`，直接使用 `[DISK]/dfs/dn2` 即可

使用 `hdfs storagepolicies` 命令管理文件/目录的存储策略，共三个子命令。

命令 | 作用
----|----
`hdfs storagepolicies -listPolicies` | 列出所有的块存储策略
`hdfs storagepolicies -setStoragePolicy -path <path> -policy <policy>` | 对指定路径设置存储策略，子目录会继承
`hdfs storagepolicies -getStoragePolicy -path <path>` | 获取指定路径的存储策略

## Mover

Mover 是 HDFS 的一个数据迁移工具，类似 Balancer. 区别在于，Mover 的目的是把数据块按照存储策略迁移，Balancer 是在不同 DataNode 直接进行平衡。如果 DataNode 挂载了多种存储类型，Mover 优先尝试在本地迁移，避免网络 IO.

使用方式: `hdfs mover -p <path>`，如果想一次性迁移所有数据，可把 path 指定为根路径，不过需要的时间也更长。

## 参考

- [Archival Storage, SSD & Memory](http://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/ArchivalStorage.html)
- [Enable support for heterogeneous storages in HDFS - DN as a collection of storages](https://issues.apache.org/jira/browse/HDFS-2832)
- [HDFS异构存储](https://blog.csdn.net/androidlushangderen/article/details/51105876)
- [Configuring Heterogeneous Storage in HDFS](https://www.cloudera.com/documentation/enterprise/5-14-x/topics/admin_heterogeneous_storage_oview.html)