+++
date = "2017-05-10T17:23:55+08:00"
draft = false
tags = ["aws", "tableau"]
categories = ["aws", "tableau"]
title = "在 AWS 上安装 Tableau Server"
slug = "install-tableau-server-on-aws-ec2"
+++

## 启动 EC2 实例

先根据 Tableau Server 的使用情况确定需要的配置，从而确定实例类型。

- AMI: Microsoft Windows Server 2012 R2 Base（简体中文）
- 类型: m4.4xlarge

启动、配置步骤略去不表，有两点需要注意：

- VPC 需要开启 3389 端口用于远程登录（RDP）
- 密钥对会用于解密登录密码

## 安装 Tableau Server

从 Tableau 官网下载然后安装，配置、激活过程比较简单，略去不表。

<!--more-->

## （可选）安装 MySQL 驱动

在 [这个页面](https://www.tableau.com/zh-cn/support/drivers)可以找到所有数据源需要的驱动程序.

下载好驱动程序，如 mysql-connector-odbc-5.3.7-winx64.msi，双击安装，提示错误。搜索了一番，应该是缺少 Visual C++ 的运行库。试过 Visual C++ Redistributable for Visual Studio 2012 Update 4 和 Visual C++ Redistributable Packages for Visual Studio 2013，最后发现后者才有用。

安装完 [Visual C++ Redistributable Packages for Visual Studio 2013](https://www.microsoft.com/zh-cn/download/confirmation.aspx?id=40784) 之后，可以成功安装mysql-connector-odbc-5.3.7-winx64.msi 。

## 安装 AWS 命令行程序

从这里下载：[https://s3.amazonaws.com/aws-cli/AWSCLI64.msi](https://s3.amazonaws.com/aws-cli/AWSCLI64.msi)

安装完后打开 cmd，运行 `aws configure` 进行配置，要有上传 S3 的权限。完成后可以运行 `aws s3 ls` 验证。

## 编写备份脚本

自动备份并且把备份文件上传到 S3。

```
@echo OFF
set Binpath="C:\Program Files\Tableau\Tableau Server\10.2\bin"
set Backuppath="C:\Backups\Tablea Server\nightly"
echo %date% %time%: *** Housekeeping started ***

rmdir %Backuppath% /S /Q

%Binpath%\tabadmin backup %Backuppath%\ts_backup -d --no-config
timeout 5

%Binpath%\tabadmin cleanup

echo %date% %time%: Uploading to S3

aws s3 cp %Backuppath% s3://marspet-tableau-backup/ --recursive --exclude "*" --include "ts_backup-*.tsbak"

echo %date% %time%: *** Housekeeping completed ***
timeout 5
```

## 从备份恢复

如果是从其他的 Tableau Server 迁移过来，可以使用备份文件迁移数据。

```
C:\Users\Administrator>"C:\Program Files\Tableau\Tableau Server\10.2\bin\tabadmi
n.bat" restore --no-config Downloads\ts_backup-2017-04-05.tsbak
```

restore 操作会关闭 Tableau Server，恢复完成后需要手动开启。

## 自动备份

使用 Task Scheduler 实现，详情见官方文档：http://technet.microsoft.com/en-us/library/cc766428.aspx
