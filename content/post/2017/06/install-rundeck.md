+++
date = "2017-06-20T14:59:27+08:00"
draft = false
tags = ["devops"]
categories = ["devops"]
title = "Centos 7 安装配置 Rundeck"
slug = "centos7-install-rundeck"
+++

## 通过 yum 安装：

```
$ sudo yum install java-1.8.0
$ sudo rpm -Uvh http://repo.rundeck.org/latest.rpm
$ sudo yum install rundeck
```

如果已经安装了 Java，第一步可以略过。安装过程中有几个步骤需要确认，一路同意（输入 y）即可。

安装完成后可以立即运行：

```
$ sudo service rundeckd start
```

但生产环境还是要修改一些默认配置。上面的安装过程会添加一个名为 rundeck 的用户和组。配置文件位于 `/etc/rundeck`:

```
$ sudo su - rundeck
$ cd /etc/rundeck/
$ ll
-rw-r-----. 1 rundeck rundeck  738 Apr 20 07:47 admin.aclpolicy
-rw-r-----. 1 rundeck rundeck 1104 Apr 20 07:47 apitoken.aclpolicy
-rw-r-----. 1 rundeck rundeck  511 Apr 20 07:47 cli-log4j.properties
-rw-r-----. 1 rundeck rundeck 1438 Jun 19 16:52 framework.properties
-rw-r-----. 1 rundeck rundeck  136 Apr 20 07:47 jaas-loginmodule.conf
-rw-r-----. 1 rundeck rundeck 7538 Apr 20 07:47 log4j.properties
-rw-r-----. 1 rundeck rundeck 2889 Apr 20 07:47 profile
-rw-r-----. 1 rundeck rundeck  549 Apr 20 07:47 project.properties
-rw-r-----. 1 rundeck rundeck 1065 Jun 20 11:54 realm.properties
-rw-r-----. 1 rundeck rundeck  579 Jun 20 11:56 rundeck-config.properties
drwxr-x---. 2 rundeck rundeck   27 Jun 19 16:52 ssl
```
<!--more-->

## 修改 admin 用户密码

用户信息在 `realm.properities` 文件，默认有一个 admin 用户，密码也是 admin. 配置格式为：

```
<username>: <password>[,<rolename> ...]
```

默认的配置是：

```
admin:admin,user,admin,architect,deploy,build
```

修改密码，并使用 MD5 替换明文密码：

```
$ java -cp /var/lib/rundeck/bootstrap/jetty-all-9.0.7.v20131107.jar org.eclipse.jetty.util.security.Password admin Abcd1234
Abcd1234
OBF:1cb01ini1ink1inm1iks1iku1ikw1caa
MD5:325a2cc052914ceeb8c19016c091d2ac
CRYPT:adMpLenKdpR12
```

上面的命令会生成几种算法加密后的密码，添加到 `realm.properities` 文件：

```
admin:MD5:325a2cc052914ceeb8c19016c091d2ac,user,admin,architect,deploy,build
```

## 配置使用 MySQL 数据库

首先得要有个 MySQL 实例，安装过程不赘述。

配置过程详见 [官方文档](http://rundeck.org/docs/administration/setting-up-an-rdb-datasource.html)

- 创建 rundeck 用户和数据库

```
$ mysql -u root -p

mysql> create database rundeck;
Query OK, 1 row affected (0.00 sec)

mysql> grant ALL on rundeck.* to 'rundeckuser'@'localhost' identified by 'rundeckpassword';
Query OK, 1 row affected (0.00 sec)
```

之后可以使用 `rundeckuser` 登录，测试是否能正常连接。

- 修改 Rundeck 配置文件

编辑 `rundeck-config.properties` 文件，修改后的内容如：

```
#dataSource.url = jdbc:h2:file:/var/lib/rundeck/data/rundeckdb;MVCC=true
dataSource.url = jdbc:mysql://localhost/rundeck?autoReconnect=true
dataSource.username = rundeckuser
dataSource.password = rundeckpassword
```

## 修改 `grails.serverURL`

```
$ sudo service rundeckd start
```

运行 Rundeck 服务，打开 http://your-server-host:4440/ 并用 admin 用户登录。登录成功后，被跳转到了 http://localhost:4440/menu/home.

编辑 `rundeck-config.properties` 文件，把 `grails.serverURL` 改成正确的地址即可。

## References

- [User Guide](http://rundeck.org/docs/manual/index.html)
- [Administrator Guide](http://rundeck.org/docs/administration/index.html)
- [API Reference](http://rundeck.org/docs/api/index.html)
