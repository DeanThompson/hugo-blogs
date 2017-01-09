+++
date = "2015-11-14T16:44:34+08:00"
draft = false
tags = ["python", "celery"]
categories = ["python", "celery"]
title = "Celery 使用简介"
slug = "a-introduction-to-celery"
+++

## Introduction

### 分布式任务队列

Celery 是一个分布式任务队列，下面是 [官网](http://www.celeryproject.org/) 的一段描述：

> Celery is an asynchronous task queue/job queue based on distributed message passing.	It is focused on real-time operation, but supports scheduling as well.

Celery 简单、灵活、可靠，是一个专注于实时处理的任务队列，同时也支持任务调度。

### 何为任务队列？

摘自 Celery 官方文档的 [中文翻译](http://docs.jinkan.org/docs/celery/getting-started/introduction.html)：

> 任务队列是一种在线程或机器间分发任务的机制。

> 消息队列的输入是工作的一个单元，称为任务，独立的职程（Worker）进程持续监视队列中是否有需要处理的新任务。

> Celery 用消息通信，通常使用中间人（Broker）在客户端和职程间斡旋。这个过程从客户端向队列添加消息开始，之后中间人把消息派送给职程。

> Celery 系统可包含多个职程和中间人，以此获得高可用性和横向扩展能力。

<!--more-->

### 适用场景

1. 可以在 Request-Response 循环之外执行的操作：发送邮件、推送消息
2. 耗时的操作：调用第三方 API、视频处理（前端通过 AJAX 展示进度和结果）
3. 周期性任务：取代 crontab

## Simple Tutorial

主要参考了官网文档：[First Steps with Celery](http://docs.celeryproject.org/en/latest/getting-started/first-steps-with-celery.html)

### 选择 Broker

下图描述了 Celery 的基本架构和工作流程。

```
+------+      +--------+      +----------------+      +--------------+
| User | ---> | Broker | ---> | Workers (1..N) | ---> | Result Store |
+------+      +--------+      +----------------+      +--------------+
```

如前文所述，Celery 用消息通信。常用的 Broker 有：

- **RabbitMQ**: RabbitMQ 功能完备、稳定，是一个非常可靠的选择，Celery 官网的评价是 "excellent choice for a production environment". 缺点是使用起来毕竟有些复杂。
- **Redis**: Redis 同样功能完备，与 RabbitMQ 相比，缺点是可能因为掉电或异常退出导致数据丢失，优点是使用简单。
- **数据库**: 能方便的集成 SQLAlchemy 和 Django ORM，缺点是性能差，但如果项目本来就用到了数据库，使用起来也非常便利，而且不需要再安装 RabbitMQ 或 Redis.
- 其它: 比如 MongoDB, Amazon SQS 还有 IronMQ

我们在这里选择使用 Reids.

### 安装

Celery 是一个 Python 的应用，而且已经上传到了 PyPi，所以可以使用 `pip` 或 `easy_install` 安装：

```bash
$ pip install celery
```

安装完成后会在 PATH （或 virtualenv 的 bin 目录）添加几个命令：celery, celerybeat, celeryd 和 celeryd-multi. 我们这里只使用 celery 命令。

### 创建 Application 和 Task

Celery 的使用方法和 Flask 很像，实例化一个 Celery 对象 `app`，然后通过 `@app.task` 装饰器注册一个 task. 下面是一个简单的例子 tasks.py：

```python
from celery import Celery

app = Celery(__name__, broker='redis://localhost:6379/0')


@app.task
def add(x, y):
    return x + y
```

### 运行 worker

在 tasks.py 文件所在目录运行

```bash
$ celery worker -A tasks.app -l INFO
```

这个命令会开启一个在前台运行的 worker，解释这个命令的意义：

- worker: 运行 worker 模块
- -A: --app=APP, 指定使用的 Celery 实例，类似 Gunicorn 的用法
- -l: --loglevel=INFO, 指定日志级别，可选：DEBUG, INFO, WARNING, ERROR, CRITICAL, FATAL

其它常用的选项：

- -P: --pool=prefork, 并发模型，可选：prefork (默认，multiprocessing), eventlet, gevent, threads.
- -c: --concurrency=10, 并发级别，prefork 模型下就是子进程数量，默认等于 CPU 核心数

完整的命令行选项可以这样查看：

```bash
$ celery worker --help
```

### 调用 task

有些 Task 可以当作一个普通的函数同步调用，这里讨论异步的方式：

```python
from tasks import add

add.delay(1, 2)
add.apply_async(args=(1, 2))
```

上面两种调用方式等价，`delay()` 方法是 `apply_async()` 方法的简写。这个调用会把 `add` 操作放入到队列里，然后立即返回一个 `AsyncResult` 对象。如果关心处理结果，需要给 `app` 配置 `CELERY_RESULT_BACKEND`，指定一个存储后端保存任务的返回值。

### 配置

前文说过 Celery 与 Flask 的使用很像，配置也是如此。一般情况下，使用 Celery 的默认配置就已经足够，但 Celery 也提供了很灵活的配置。下面是两种配置方式，[官方文档](http://docs.celeryproject.org/en/latest/configuration.html) 可以查看所有的配置项及默认值。

#### 直接修改配置

单个：

```python
app.conf.CELERY_TASK_SERIALIZER = 'json'
```

或批量（支持 `dict` 语法）：

```python
app.conf.update(
    CELERY_TASK_SERIALIZER='json',
    CELERY_ACCEPT_CONTENT=['json'],  # Ignore other content
    CELERY_RESULT_SERIALIZER='json',
    CELERY_TIMEZONE='Europe/Oslo',
    CELERY_ENABLE_UTC=True
)
```

#### 配置模块

类似 Flask，对于比较大的 Celery 项目，配置模块（configuration module）是更好的选择。Celery 对象有个 `config_from_object` 方法，读取一个 object (py 文件或 class)来更新配置。

```python
BROKER_URL = 'redis://localhost:6379/0'

CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT=['json']
CELERY_TIMEZONE = 'Europe/Oslo'
CELERY_ENABLE_UTC = True
```

把上面的内容保存为 `celeryconfig.py` 文件，然后：

```python
app.config_from_object('celeryconfig')
```
