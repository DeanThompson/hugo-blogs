+++
date = "2015-03-15T13:31:49+08:00"
draft = false
tags = ["ssh", "linux"]
categories = ["linux"]
title = "重用 SSH 连接"
slug = "reuse-ssh-connection"
+++

平时需要经常用到 SSH，比如登录远程服务器，用 Git 推送和更新代码等。建立一次 SSH 连接可能并不需要多久长时间，但是如果要频繁登录同一台服务器，就未免显得有些繁琐和浪费时间。如果是用用户名和密码登录，每次都要输入密码就更加让人崩溃。还有使用 Git 的时候，短时间内可能需要经常 `git pull` 和 `git push`，如果每次操作都需要重新建立连接，等待过程就让人心生厌恶了。

实际上，SSH 有个「鲜为人知」的特性可以做到重用连接，只有在第一次登录的时候会创建新的连接，后续的会话都可以重用这个已经存在的连接。这样，后续的登录就会非常快，而且不需要输入密码认证。配置也很简单，直接上代码。

修改 `~/.ssh/config` 文件，添加如下配置：

```sshconfig
Host *
    ControlMaster auto
    ControlPath /tmp/ssh_mux_%h_%p_%r
    ControlPersist 600
```

<!--more-->

意思也很好理解：

`Host *` 这一行表示下面这些配置和规则影响到的 host，`*` 表示所有的远程 host 都生效。如果要指定某个（些）特定的 host，可以使用类似 `Host *.example.com` 的配置。

`ControlMaster auto` 这个选项告诉 SSH 客户端尝试重用现有的连接（master connection）。

`ControlPath` 指定了这个连接的 socket 保存的路径，这里配置的是在 /tmp 目录，实际上可以在任何有读写权限的路径下。`/tmp/ssh_mux_%h_%p_%r` 配置了 socket 文件名，`%h` 表示远程主机名（host），`%p` 表示远程 SSH 服务器的端口（port），`%r` 表示登录的远程用户名（remote user name）。这些 socket 可以随时删掉（`rm`），删除后首次会话又会创建新的 master 连接。曾经遇到过这种情况，本地断网了，打开的几个远程终端都卡死，网络恢复后也一直这样，甚至打开新的终端也登录不上。这个时候只需要把之前的 socket 文件都删掉，重新登录就可以了。

`ControlPersist` 这个选项比较重要，表示在创建首个连接（master connection）的会话退出后，master 连接仍然在后台保留，以便其他复用该连接的会话不会出现问题。这个特性在使用 Git 的时候就非常有用，在频繁提交和拉代码的时候，每次 SSH 会话都是很短暂的，如果 master 连接能保持在后台，后续的操作就会如丝般顺滑。

只需要添加上面几行配置，SSH 的体验就瞬间上升了好几个档次，简直是懒人必备。

