+++
date = "2015-11-05T16:52:12+08:00"
draft = false
tags = ["python", "flask", "tornado", "cache"]
categories = ["python", "flask", "tornado", "cache"]
title = "Tornado 和 Flask 应用缓存响应结果"
slug = "cache-response-in-tornado-and-flask"
+++

写 API 的时候，总是会想着如何能提升性能。在一般的 Web 应用里，基本上没什么 CPU 密集型的计算，大部分时间还是消耗在 IO 上面：查询数据库、读写文件、调用第三方 API 等。有些可以异步的操作，比如发送注册邮件、手机验证码等，可以用任务队列来处理。在 Python 的生态里，Celery 就是一个很成熟的解决方案。但是对于很多查询请求，还是需要同步返回的。

如果真的遇到性能问题，正确的做法是先找出性能瓶颈，然后对症下药。比如优化数据库索引、优化数据库查询语句、优化算法和数据结构，加速查询和计算。但是最快的计算就是不算——或只计算一次，也就是把计算（查询）的结果缓存起来，以后相同条件的计算（查询）直接从缓存里获取，而不需要重新计算（查询）。

对于耗时的计算，缓存是一种非常有效的优化手段。但缓存也不是万能的，引入缓存的同时，一些其他问题或需要注意的事情也随之而来，比如数据同步、缓存失效、命中率、分布式等。这里不深入探讨这些问题，仅针对下面这种场景，使用缓存来优化 API 性能：

- GET 查询
- 查询很耗时
- 相同条件、不同时间（或某段时间内）的查询结果是一致的

比如获取静态页面（也可以通过 Nginx 直接返回），查询某些元数据列表（如国家列表、产品分类等）。

<!--more-->

## 基本思想

“一码胜千言”，直接上代码描述一下：

```python
def cachable_get(kwargs, on_cache_missing, timeout=300):
    key = make_key(kwargs)	# 计算出一个 key
    value = cache.get(key)	# 查询缓存
    if not value:
        value = on_cache_missing(kwargs)	# 缓存没有命中，计算一次
        cache.set(key, value, timeout)	# 把计算结果写入缓存
    return value
```

实际上也就是：先查缓存，如果有缓存没命中，再计算并把结果写入缓存。这种机制类似于中间件，或 Python 里的装饰器。

## Tornado 的实现

Tornado 的 `tornado.web.RequestHandler` 有两个方法：`prepare` 和 `write`。前者会在执行业务代码前执行，后者用于写入响应结果。所以可以在 `prepare` 里查询缓存，如果命中就直接返回。没有命中的请求会执行业务代码，然后在 `write` 里顺便写入缓存。

在 Tornado 项目里，通常的做法是从 `tornado.web.RequestHandler` 派生一个 `BaseHandler` 用于项目内 Handler 的统一基类，方便在 `BaseHandler` 里做一些统一的处理。如果在 `BaseHandler` 的 `prepare` 和 `write` 方法实现缓存机制，会影响到所有子类的表现，这样可控性和扩展性就会差一点。推荐的做法是用 Mixin.

```python
# -*- coding: utf-8 -*-

try:
    import cPickle as pickle
except ImportError:
    import pickle

import functools
from hashlib import sha1


class CacheMixin(object):
    @property
    def cache(self):
        return self.application.cache

    def _generate_key(self):
        key = pickle.dumps((self.request.path, self.request.arguments))
        return self._with_prefix(sha1(key).hexdigest())

    def _with_prefix(self, key):
        return '%s:%s' % (self.request.path.strip('/'), key)

    def write_cache(self, chunk):
        super(CacheMixin, self).write(chunk)

    def prepare(self):
        super(CacheMixin, self).prepare()
        key = self._generate_key()
        cached = self.cache.get(key)
        if cached is not None:
            self.write_cache(pickle.loads(cached))
            self.finish()

    def write(self, chunk):
        key = self._generate_key()
        expiration = getattr(self, 'expiration', 300)
        self.cache.set(key, pickle.dumps(chunk), expiration)
        super(CacheMixin, self).write(chunk)


def set_cache_timeout(expiration=300):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(handler, *args, **kwargs):
            handler.expiration = expiration
            return func(handler, *args, **kwargs)

        return wrapper

    return decorator
```

`CacheMixin` 在定义 Handler 时作为基类传入，覆盖 `tornado.web.RequestHandler` 的 `prepare` 和 `write`，实现缓存机制。`self.application.cache` 意味着初始化 `tornado.web.Application` 时需要配置一个 `cache` 属性，至少需要实现 `get` 和支持超时的 `set` 方法。常见的是定义一个 `CacheBackend` 和一套 `get`, `set` 接口，然后封装不同的缓存实现，比如 Redis，Memcache 等。

`set_cache_timeout` 提供了自定义缓存失效时间的能力，这个装饰器不是必须的，与之等价的方式是在 Handler 的 `get` 方法的第一行（或第一个调用 `self.write` 语句前）加上：`self.expiration = TIMEOUT_IN_SECONDS`. 

一个没什么实际意义的使用示例：

```python
Class HelloHandler(CacheMixin, tornado.web.RequestHandler):
    
    @set_cache_timeout(86400)
    def get(self):
        self.write("Hello world!")
```

## Flask 的实现

Flask 里可以用 `before_request` 和 `after_request` 这两个 hooks 实现 Tornado 里覆盖 `prepare` 和 `write` 来缓存所有请求，具体实现大同小异。也可以用装饰器来获得更好的灵活性。

在看具体实现之前，先推荐一个 Flask 的缓存扩展：[Flask-Cache](https://pythonhosted.org/Flask-Cache/). Flask-Cache 基于 `werkzeug.contrib.cache`，后者定义了一套缓存接口和实现了多种不同 Backend 的缓存实现；Flask-Cache 在此基础上针对 Flask 做了一些应用性集成以及提供了一些其他的辅助函数。

下面的例子用的是 Flask-Cache，后端用 Redis，具体的配置见 Flask-Cache 的官方文档。

```python
try:
    import cPickle as pickle
except ImportError:
    import pickle

import hashlib
import functools

from flask import g


class cached_response(object):
    def __init__(self, timeout=300):
        self.timeout = timeout or 300

    def _generate_key(self):
        data = pickle.dumps((request.path, request.values))
        key = hashlib.sha1(data).hexdigest()
        return self._with_prefix(key)

    @staticmethod
    def _with_prefix(key):
        return '%s:%s' % (request.path, key)

    def __call__(self, view_func):
        @functools.wraps(view_func)
        def decorator(*args, **kwargs):
            key = self._generate_key()
            response = cache.get(key)
            if response:
                return response

            response = view_func(*args, **kwargs)

            # 允许 view 函数通过设置 g.disable_cache = True 来控制不缓存本次请求的结果
            if getattr(g, 'disable_cache', False):
                return response
            
            # 只缓存 200 的请求结果
            if response.status_code == 200:
                cache.set(key, response, self.timeout)
        
            return response

        return decorator
```

`cached_response` 是一个基于类的装饰器实现，接受 `timeout` 参数指定缓存失效时间。用 `request.path` 和 `request.values` 序列化后的哈希值来标示相同的参数的请求（与 Tornado 版本类似）。上面的实现还展现出了一些可定制性：

- 只缓存 StatusCode 为 200 的请求结果
- 允许 endpoint 通过设置 `g.disable_cache = True` 来控制不缓存

除了这两点，还可以做其他定制，比如通过请求参数传入 `nocache=1` 来控制获取实时结果，通过设置 `g.cache_timeout = 100` 来覆盖默认的缓存失效时间。

使用起来也很简单，只需要注册一个装饰器就可以：

```python
@app.route('/hello/')
@cached_response(86400)
def hello():
    return "Hello, world!"
```

## 结语

上面展示了在 Tornado 和 Flask 项目里缓存请求结果的实现方法，实际使用的时候，还是要结合具体情况做定制和调整。缓存也是一把双刃剑，在享受缓存带来性能提升的同时也要注意可能引入的问题。