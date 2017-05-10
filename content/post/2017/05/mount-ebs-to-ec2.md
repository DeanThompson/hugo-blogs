+++
date = "2017-05-10T17:41:54+08:00"
draft = false
tags = ["aws", "ec2"]
categories = ["aws"]
title = "EC2 挂载 EBS"
slug = "mount ebs to ec2"
+++

创建 EC2 实例的时候可以选择添加 EBS 卷，在实例运行后，需要手动挂载上去。

详情见 [EBS 的文档](http://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/ebs-using-volumes.html)

## 用 `lsblk` 命令查看所有可用的磁盘及其安装点

```
$ lsblk
NAME    MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
xvda    202:0    0   8G  0 disk
`-xvda1 202:1    0   8G  0 part /
xvdb    202:16   0  30G  0 disk
```

其中 `xvda1` 是根设备，挂载到了 `/`；`xvdb` 是刚才添加的 EBS 卷，还没有挂载。

<!--more-->

## 确定是否需要在卷上创建文件系统。

如果是新的 EBS，是一个原始的块存储设备，需要先创建文件系统才能安装使用。从快照还原的卷可能已经含有文件系统。

```
$ sudo file -s /dev/xvdb
/dev/xvdb: data

$ sudo file -s /dev/xvda1
/dev/xvda1: Linux rev 1.0 ext4 filesystem data, UUID=9fbb7c51-0409-4b50-ad40-068dcfe4bc89, volume name "cloudimg-rootfs" (needs journal recovery) (extents) (large files) (huge files)
```

可以看到 `/dev/xvdb` 上面还没有文件系统，需要手动创建:

```
$ sudo mkfs -t ext4 /dev/xvdb
mke2fs 1.42.13 (17-May-2015)
Creating filesystem with 7864320 4k blocks and 1966080 inodes
Filesystem UUID: 2a0dae23-7b6e-42ec-95e1-df58f29520a4
Superblock backups stored on blocks:
     32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
     4096000

Allocating group tables: done
Writing inode tables: done
Creating journal (32768 blocks): done
Writing superblocks and filesystem accounting information: done

$ sudo file -s /dev/xvdb
/dev/xvdb: Linux rev 1.0 ext4 filesystem data, UUID=2a0dae23-7b6e-42ec-95e1-df58f29520a4 (extents) (large files) (huge files)
```

注意：`mkfs` 会格式化卷，删除所有数据。

## 创建安装点，也就是要挂载的位置:

```
$ sudo mkdir /data
```

## 挂载

```
sudo mount /dev/xvdb /data/
```

## 用 `df` 命令磁盘空间

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            489M     0  489M   0% /dev
tmpfs           100M  3.1M   97M   4% /run
/dev/xvda1      7.8G  1.9G  5.5G  26% /
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           496M     0  496M   0% /sys/fs/cgroup
tmpfs           100M     0  100M   0% /run/user/1000
/dev/xvdb        30G   44M   28G   1% /data
```
