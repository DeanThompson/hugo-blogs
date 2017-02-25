+++
date = "2016-04-15T11:47:00+08:00"
draft = false
tags = ["mongodb", "aws", "db"]
categories = ["mongodb"]
title = "MongoDB Replica Set 重新同步"
slug = "mongodb-replica-set-resync"
+++

生产环境上用了 MongoDB，三个节点组成的 ReplicaSet（复制集）。部署好后，应用一直没出过问题，所以平时也没管过。今天早上突然想上服务器看看，于是登录了 primary 节点查看日志，发现这条日志不断重复：

```
2016-04-15T03:02:39.470+0000 W NETWORK  [ReplExecNetThread-28676] Failed to connect to 172.31.168.48:11102, reason: errno:111 Connection refused
```

其实就是有个 secondary 节点一直连接不上。不太可能是网络问题，所以很可能是那个节点的 mongod 进程挂掉了。登录上 secondary 节点，mongod 进程果然不在运行；查看日志发现最后一条是在 2016-03-21. 一时间有两个疑问涌上心头：

1. 为什么会挂掉？
2. 如何修复？

<!--more-->

当务之急是先修复集群，这一点官方文档有说明：[Resync a Member of a Replica Set](https://docs.mongodb.org/manual/tutorial/resync-replica-set-member/). 其实就是删除数据文件，然后通过 initial sync 来重新同步。有两种 initial sync 的方式：

1. 清空数据目录，重启 mongod 实例，让MongoDB进行正常的初始化同步。这是个简单的方式，但是耗时较长。
2. 为该机器从其他节点上复制一份最近的数据文件，并重启。操作步骤较多，但是最为快速。

考虑到数据量并没有很多，所以决定使用第一种比较简单的方式。重启好后，发现数据目录很快就新建了很多文件。和 primary 节点对比，文件名和大小均一致；primary 节点和另一个 secondary 节点也不再出现连接失败的日志。

遗憾的是，挂掉的原因却一直没有找到。日志文件里没有发现异常，`history` 也没发现有 `kill` 的记录。
幸运的是，集群很快就恢复了，应用不受影响，数据也没丢失。
