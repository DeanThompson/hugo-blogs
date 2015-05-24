+++
date = "2015-03-20T11:00:13+08:00"
draft = false
tags = ["python", "fabric", "deploy", "linux"]
categories = ["python"]
title = "用 Fabric 来发布代码"
slug = "deploy-applications-using-fabric"
+++

写代码的时候很爽，本地开发一下子完成了，等到部署发布代码的时候就有些烦了。开发环境、测试环境、生产环境，有些配置是因环境而异的，在我们的 Python 项目里，一直保留这样的习惯：

1. 使用 py 文件做配置文件
2. 固定的配置，放在 settings.py 里
3. 不同环境可能要修改的，放在 site_settings.py 里，然后在 settings.py 里全部 import 进去
4. 需要使用配置的时候，只需要 `settings.FOO` 就可以

实际上，这样的习惯在发布代码时带来了一些小麻烦。曾经用过这些方式发布 Python 代码：

1. rsync. 实际上用 rsync 发布的体验还挺好的，每次只会同步更新过的文件，而且可以配置不需要同步的文件。在使用 rsync 时，site_settings.py 是没有同步的。但是个人体验，rsync 也有不好的地方，首先就是需要依赖 rsync 服务，在远程机器和本地都要配置；二是不好做备份。

2. git. 应该说，git 应该是我最喜欢的发布方式了，本地 push，远程 pull，完事；而且还很好备份和回滚。再有，如果我「作死」在服务器上修改调试代码，能方便的提交到版本库。但是，考虑到安全问题，很多 git 服务器都搭建在内网，服务器上根本就无法访问到。

3. scp. 这是很 low 的一种做法，也基本上是我最后的选择。刚入职到现在这家公司，新部门，有点蛮荒时代的感觉。（非常简陋的）git 服务器在内网，所以在服务器上搞了一下 rsync，配置好后发现本地无法连接到服务器的 873 端口（不知道是不是公司配置了防火墙）。一时间就堕落到选择了 scp. 好处几乎没有，不方便的地方倒是一大堆：不方便增量更新，只能全部覆盖，考虑到 site_settings.py 的存在，这个很不方便；不方便设置要排除的文件，如果想省事把整个项目 scp 过去，就会把 .git 目录和 .pyc 文件也拷过去，无用而慢。


但实际上这些天我还使用了好几次 scp 来发布代码，一直在重复体力劳动。终于，想起了 [fabric](http://www.fabfile.org/)，带我「脱离苦海」。

fabric 使用起来非常简单，对我来说，只需要简单几行代码的配置，就能自动完成我之前繁复的体力劳动。

```python
# -*- coding: utf-8 -*-

import os

from fabric.api import env, local, cd, lcd, put, run


def prod():
    env.hosts = ["123.123.123.123"]
    env.user = "test"
    # env.password = ""  # 如果这里写了密码，在发布时就不用输密码了


def pyclean():
    local("pyclean .")      # local 函数执行本地命令


def deploy():
    pyclean()

    local_app_dir = "~/workspace/projects/"
    remote_app_dir = "~/projects"

    # lcd 是 「local cd」，cd 是在远程服务器执行 cd
    with lcd(local_app_dir), cd(remote_app_dir):
        # 1. backup
        run("rm -rf SomeProj.bak")          # run 是在远程服务器上执行命令
        run("mv SomeProj SomeProj.bak")

        # 2. transfer
        d = os.path.join(remote_app_dir, "SomeProj")
        run("mkdir -p %s" % d)
        put("SomeProj/*", "SomeProj")   # put 把本地文件传输到远程（看了下源码，是 FTP 协议）

        # 3. replace site_settings.py
        for subdir in ["apps", "admin", "core"]:
            src = "SomeProj.bak/%s/configs/site_settings.py" % subdir
            dest = "SomeProj/%s/configs/site_settings.py" % subdir
            cmd = "cp %s %s" % (src, dest)
            run(cmd)
```

把上面的代码保存为 fabfile.py，要发布的时候，只需在 fabfile.py 所在的路径执行：

```bash
fab prod deploy
```

因为在 env 配置里没有设置密码，所以执行过程中需要手动输入一下。然后 fabric 就把所有你指定的事情都干了，一次配置，终生享福。

实际上还可以配置在发布好代码后，重启应用（supervisorctl）。为了避免意外，和某些情况下需要修改 site_settings.py，所以就没有这么干，而是选择每次都手动重启。

fabric，又是一个懒人必备的神器。

