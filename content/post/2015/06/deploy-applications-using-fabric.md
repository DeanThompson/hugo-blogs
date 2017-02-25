+++
date = "2015-06-12T14:00:13+08:00"
draft = false
tags = ["python", "fabric", "deployment"]
categories = ["python", "tools"]
title = "用 Fabric 实现自动化部署"
slug = "deploy-applications-using-fabric"
+++

写完代码测试通过之后，终于松一口气，然后可以愉快的部署上线了。但是问题随之而来：如何部署？或者如何能更自动化的部署？

部署应用是一系列的操作，就环境而言，分为本地和远程服务器，就操作而言，大概包括提交代码、备份代码、更新代码、安装依赖、迁移数据库、重启服务等流程。其中除了提交代码这一步是在本地完成，其余操作都需要在服务器环境执行。

上面的流程当中，有一个很重要的，就是如何同步代码（提交、备份、更新）。就我的经验，了解或用过这些方式：

- rsync: rsync 是一个文件同步的工具，如果配置好使用起来体验也不错。但是有很多缺点：
	- 配置复杂，命令行参数多
	- 需要在服务器上运行 rsyncd，默认监听 873 端口（可能会有防火墙）
- scp: scp 底层用的是 SSH 协议，所以只要服务器上运行了 sshd 就可以双向 copy 文件。对于文件传输来说，scp 比 rsync 体验差的地方有：
	- 不能增量更新，每次都是全部传输
	- 不能配置忽略文件（.git 怎么办？）
- git: 就个人而言，git 是最方便的部署方式了，有版本控制，可以增量更新，可以配置忽略文件，使用简单。实际上只要有可能，都推荐用 git 来发布代码。但问题在于，很多公司的 git 服务器都是在内网的，所以在服务器上无法访问。

很幸运的是，我们有一个公网可以访问的 git 服务器，所以可以用 git 来发布代码。发布完代码后就是后续的一系列操作了，最原始的方式，是登录到服务器，然后一步一步敲命令执行下来。但是如果要频繁部署的话（快速迭代时肯定要经常更新代码），这就变成了繁复的体力劳动，而且容易出错（漏了流程，看花眼了）。于是就想到了脚本，把这些操作写成 shell 脚本，然后执行脚本就好了。这是一个很大的进步，然而仍然存在一个问题：从本地环境到远程环境，需要登录，导致了流程上的阻断。

[Fabric](http://www.fabfile.org/) 是 Python 编写的一个可以实现自动化部署和系统维护的命令行工具，只需要写一些简单的 Python 代码就能轻松解决上面提到的所有问题。Fabric 底层用的是 SSH 协议，提供了一系列语义清晰的 API 来组合实现部署任务。

<!--more-->

## 安装

Fabric 是 Python 编写的工具，所以可以用 pip 来安装：

```bash
sudo pip install fabric
```

如果是 Ubuntu 系统，还可以用 apt-get 安装：

```bash
sudo apt-get install fabric
```

安装完成后，会生成一个 `fab` 命令，这个命令会读取当前路径在的 fabfile.py 并执行相应的任务。

## Hello, world!

先来看一个简单的例子，用 `fab` 命令执行一个输出 `Hello, world!` 的任务。

新建一个文件，fabfile.py: 

```python
def hello():
	print 'Hello, world!'
```

在 fabfile.py 所在的路径执行：

```bash
fab hello
```

可以看到有这样的输出：

```
Hello, world!

Done.
```

可以给任务传递参数，修改 fabfile.py:

```python
def hello(name="world"):
    print "Hello, %s!" % name
```

用 `fab` 命令执行：

```bash
$ fab hello

Hello, world!

Done.

$ fab hello:name=leon

Hello, leon!

Done.
```

这个例子除了展示 fab 运行任务和传递参数之外，没有什么实际意义，接下来用一个接近真实的场景来展示如何用 Fabric 部署。

## 部署应用

假设这样一个场景，有个 Python 项目取名 usercenter，用 git 做版本控制，用 supervisor 做进程管理。一次完整的部署过程可能包括这些流程：

```bash
# 本地
$ cd /path/to/userenter
$ git pull
$ git add -A
$ git commit -m "commit message"
$ git push

# 远程
$ cd /path/to/usercenter
$ workon usercenter		# virtualenv
$ git pull				# 更新代码
$ pip install -r requirements.txt		# 安装依赖
$ python manage.py db migrate			# 数据库迁移
$ supervisorctl restart usercenter	# 重启服务
```

我们现在用 Fabric 来一次性完成上面所有操作（假设第一次部署是手工执行的，现在只处理更新／升级的任务）。在 usercenter 项目的根目录下新建 fabfile.py 文件：

```python
# -*- coding: utf-8 -*-

from fabric.api import env, local, cd, run
from fabric.context_managers import prefix


def production():
	""" 设置 production 环境 """
	env.hosts = ["production@123.123.123.123:22"]
	env.key_filename = "/path/to/key_file"
	# env.password = "123456"	# password 和 keyfile 两者只需要一个就可以


def staging():
	""" 设置 staging 环境 """
	env.hosts = ["staging@111.111.111.111:22"]
	env.password = "123456"		# 如果不写密码，会在 fab 执行时有交互提示输入密码


def prepare():
    """ 本地提交代码，准备部署 """
	local("git pull")	# local 用于执行本地命令
	local("pip freeze > requirements.txt")
	local("git add -p && git commit")	＃ 会有交互输入 commit message
	local("git push")


def update():
	""" 服务器上更新代码、依赖和迁移 """
	# cd 用于在服务器上执行 cd 命令，本地环境对应的 api 是 lcd (local cd)
	with cd("/path/to/usercenter"), prefix("workon usercenter"):
		run("git pull")			# run 用于服务器上执行命令
		run("pip install -r requirements.txt")
		run("python manage.py db migrate")
		run("supervisorctl restart usercenter")

def deploy():
	prepare()
	update()
```

OK, 完成。具体的意义代码里面都有注释，不赘述。需要注意的是 `production` 和 `staging` 分别设置了两种不同的环境。

```bash
# 部署到 production 环境
$ fab production deploy

# 部署到 staging 环境
$ fab staging deploy
```

执行过程中可能会有些交互，按提示输入相应信息，然后等着执行完成就好了。如果一切顺利（应该是这样），就完成了 usercenter 的部署了，整个过程只需要敲一行命令，是不是非常方便？

## More...

上面的例子基本上是可以在实际环境中使用的，不过还是有很多内容没有覆盖到，比如错误处理，多服务器部署，并行等。Fabric 默认是串行执行的，如果有多个远程服务器，是一个一个顺序执行。执行过程中如果发生异常，任务会直接中断，所以可能需要有错误处理。

上面这些（还有很多）内容都可以在 Fabric 的文档上（非常详细）找到相应的内容，下面给出一些参考链接，结合文档和自己的实际情况，多用几次就能定制出能满足自己需求的 Fabric 任务：

- Fabric 官网: [http://www.fabfile.org/](http://www.fabfile.org/)
- Overview and Tutorial: [http://docs.fabfile.org/en/1.10/tutorial.html](Overview and Tutorial)
- Fabric 文档: [http://docs.fabfile.org/en/1.10/index.html](http://docs.fabfile.org/en/1.10/index.html)
- Python fabric实现远程操作和部署（By wklken）: [http://wklken.me/posts/2013/03/25/python-tool-fabric.html](http://wklken.me/posts/2013/03/25/python-tool-fabric.html)
