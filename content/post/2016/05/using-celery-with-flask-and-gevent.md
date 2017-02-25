+++
date = "2016-05-17T16:42:37+08:00"
draft = false
tags = ["python", "celery", "flask", "gevent"]
categories = ["python", "flask", "celery"]
title = "在 Flask 项目的 celery 中使用 gevent"
slug = "using-celery-with-flask-and-gevent"
+++

[在 Flask 项目中使用 Celery](/posts/2015/11/using-celery-with-flask/) 这篇文章谈到了如何在 Flask 项目中集成 Celery，也讲了在 celery 任务中引用 Flask 的 application context 的方法。一般情况下那样使用是没问题的，但是如果需要在 task 中使用 gevent，就需要一些额外的改进。至少有两点。

## 1. 使用 gevent 并发模型

如果在 task 中要使用 gevent，就必须使用 gevent 并发模型。这很好处理，只需要修改启动选项就行：

```bash
$ celery worker -A celery_worker.celery -P gevent -c 10 -l INFO
```

上面的命令，`-P` 选项指定 pool，默认是 prefork，这里是 gevent; `-c` 设置并发数。

<!--more-->

## 2. 引用 Flask 的 application context

这个问题也是在 [在 Flask 项目中使用 Celery](/posts/2015/11/using-celery-with-flask/) 中重点讨论的，在这种场景下，上文的解决方法起不到作用，仍然会报错（具体原因不太懂，知道的朋友请不吝赐教）。解决方案就是，把需要引用 Flask app 的地方（如 app.config），放到 Flask 的 application context 里执行，如：

```python
with app.app_context():
    print app.config.get('SOME_CONFIG_KEY')
```

在实际应用中，我最后写了个装饰器来实现这个目的。简单介绍一下场景，项目用到了 Flask-Cache，项目启动时会创建全局单例 `cache`，并在 `create_app` 中进行初始化。在 Flask-Cache 初始化时，会把当前的 Flask app 对象绑定到实例 `cache` 中，所以可以尝试从这里获取 app 对象。

代码的目录结构与之前一样：

```
.
├── README.md
├── app
│   ├── __init__.py
│   ├── config.py
│   ├── forms
│   ├── models
│   ├── tasks
│   │   ├── __init__.py
│   │   └── email.py
│   └── views
│   │   ├── __init__.py
│   │   └── account.py
├── celery_worker.py
├── manage.py
└── wsgi.py
```

装饰器：

```python
def with_app_context(task):
    memo = {'app': None}

    @functools.wraps(task)
    def _wrapper(*args, **kwargs):
        if not memo['app']:
            try:
                # 尝试从 cache 中获取 app 对象，如果得到的不是 None，就不需要重复创建了
                app = cache.app
                _ = app.name
            except Exception:
                from app import create_app

                app = create_app()
            memo['app'] = app
        else:
            app = memo['app']

        # 把 task 放到 application context 环境中运行
        with app.app_context():
            return task(*args, **kwargs)

    return _wrapper
```

使用：

```python
@celery.task()
@with_app_context
def add(x, y):
    print app.config.get('SOME_CONFIG_KEY')
    return x + y
```
