+++
date = "2015-11-14T16:57:03+08:00"
draft = false
tags = ["python", "celery", "flask"]
categories = ["python", "flask", "celery"]
title = "在 Flask 项目中使用 Celery"
slug = "using-celery-with-flask"
+++

[前一篇 Blog](/posts/2015/11/a-introduction-to-celery/) 简单介绍了 Celery 及其用法，现在我们看看在 Flask 项目中如何使用 Celery.

注意，这篇 Blog 严重参考了这两篇文章：

1. [Using Celery With Flask](http://blog.miguelgrinberg.com/post/using-celery-with-flask): 写了一个完整而且有意义的例子来展示如何在 Flask 中使用 Celery.
2. [Celery and the Flask Application Factory Pattern](http://blog.miguelgrinberg.com/post/celery-and-the-flask-application-factory-pattern): 是上文的姊妹篇，描述的是更为真实的场景下，Celery 与 [Flask Application Factory](http://flask.pocoo.org/docs/0.10/patterns/appfactories/) 的结合使用。

<!--more-->

## Minimum Example

Celery 的一些设计和概念，与 Flask 很像，在 Flask 项目中集成 Celery 也很简单，不像 Django 或其他框架需要扩展插件。首先来看个最简单的例子 example.py：

```python
import uuid

from flask import Flask, request, jsonify
from celery import Celery

app = Flask(__name__)
app.config['CELERY_BROKER_URL'] = 'redis://localhost:6379/0'
app.config['CELERY_RESULT_BACKEND'] = 'redis://localhost:6379/0'

celery = Celery(app.name, broker=app.config['CELERY_BROKER_URL'])
celery.conf.update(app.config)


@celery.task
def send_email(to, subject, content):
    return do_send_email(to, subject, content)


@app.route('/password/forgot/', methods=['POST'])
def reset_password():
    email = request.form['email']
    token = str(uuid.uuid4())
    content = u'请点击链接重置密码：http://example.com/password/reset/?token=%s' % token
    send_email.delay(email, content)
    return jsonify(code=0, message=u'发送成功')


if __name__ == '__main__':
    app.run()
```

启动 Celery worker:

```bash
$ celery worker -A example.celery -l INFO
```

启动 Web server:

```bash
$ python example.py
```

当然，实际应用在生产环境下，不能直接用 Flask 自带的 server，需要使用 Gunicorn 这样的 WSGI 容器，或 uWSGI. 而且 Celery worker 进程和 Web server 进程应该用 supervisord 管理起来。

## Becoming Bigger

这是个最简单的例子，实际应用会比这个复杂很多：有很多模块，更复杂的配置，更多的 task 等。在这种情况下，Flask 推荐使用 [Application Factory Pattern](http://flask.pocoo.org/docs/0.10/patterns/appfactories/)，也就是定义一个 function，在这里创建 Flask app 对象，并且处理注册路由（blueprints）、配置 logging 等一系列初始化操作。

下面我们看看在更大的 Flask 项目里，应该如何使用 Celery.

### 项目结构

首先来看一下整个项目的结构：

```text
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

这个图里省略了很多细节，简单解释一下：

- 项目的根目录下，有个 `celery_worker.py` 的文件，这个文件的作用类似于 `wsgi.py`，是启动 Celery worker 的入口。
- app 包里是主要业务代码，其中 tasks 里定义里一系列的 task，提供给其他模块调用。

### 主要代码。

- app/config.py

```python
class BaseConfig(object):
    CELERY_BROKER_URL = 'redis://localhost:6379/2'
    CELERY_RESULT_BACKEND = 'redis://localhost:6379/2'
    CELERY_TASK_SERIALIZER = 'json'
```

`BaseConfig` 是整个项目用到的配置的基类，实际上还会派生出 `DevelopmentConfig`, `StagingConfig` 和 `ProductionConfig` 等类。这里不讨论配置的细节，也只关心和 Celery 相关的配置项。

- app/\__init__.py

```python
from celery import Celery
from flask import Flask

from app.config import BaseConfig

celery = Celery(__name__, broker=BaseConfig.CELERY_BROKER_URL)


def create_app():
    app = Flask(__name__)
    # ....
    celery.conf.update(app.config)	# 更新 celery 的配置
    # ...
    return app
```

- app/tasks/email.py

```python
from flask import current_app
from celery.util.log import get_task_logger

from app import celery

logger = get_task_logger(__name__)


@celery.task
def send_email(to, subject, content):
    app = current_app._get_current_object()
    subject = app.config['EMAIL_SUBJECT_PREFIX'] + subject
    logger.info('send message "%s" to %s', content, to)
    return do_send_email(to, subject, content)

```

- app/views/account.py

```python
import uuid

from flask import Blueprint, request,jsonify

from app.tasks.email import send_email

bp_account = Blueprint('account', __name__)


@bp_account.route('/password/forgot/', methods=['POST'])
def reset_password():
    email = request.form['email']
    token = str(uuid.uuid4())
    content = u'请点击链接重置密码：http://example.com/password/reset/?token=%s' % token
    send_email.delay(email, content)
    return jsonify(code=0, message=u'发送成功')
```

- ceelry_worker.py

```python
from app import create_app, celery

app = create_app()
app.app_context().push()
```

这个 `celery_worker.py` 文件有两个操作：

1. 创建一个 Flask 实例
2. 推入 Flask application context

第一个操作很简单，其实也是初始化了 celery 实例。

第二个操作看起来有些奇怪，实际上也很好理解。如果用过 Flask 就应该知道 Flask 的 [Application Context](http://flask.pocoo.org/docs/0.10/appcontext/) 和 [Request Context](http://flask.pocoo.org/docs/0.10/reqcontext/). Flask 一个很重要的设计理念是：在一个 Python 进程里可以运行多个应用（application），当存在多个 application 时可以通过 `current_app` 获取当前请求所对应的 application. `current_app` 绑定的是当前 request 的 application 的引用，在非 request-response 环境里，是没有 request context 的，所以调用 `current_app` 就会抛出异常（`RuntimeError: working outside of application context`）。创建一个 request context 没有必要，而且消耗资源，所以就引入了 application context. 

`app.app_context().push()` 会推入一个 application context，后续所有操作都会在这个环境里执行，直到进程退出。因此，如果在 tasks 里用到了 `current_app` 或其它需要 application context 的东西，就一定需要这样做。（默认情况下 Celery 的 pool 是 prefork，也就是多进程，现在这种写法没有问题；但是如果指定使用 gevent，是没用的。这种情况下有别的解决方案，以后会写文章讨论。）

### 运行

在项目的根路径下启动 Celery worker:

```bash
$ celery worker -A celery_worker.celery -l INFO
```

## 总结

上面两个例子，实际上主要的差别就是初始化方式和模块化，还有需要注意 Flask 的 application context 问题。文章内容比较简单，文中的一些链接是很好的扩展和补充，值得一看。