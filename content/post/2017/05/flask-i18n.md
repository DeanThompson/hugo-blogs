+++
date = "2017-05-10T17:48:17+08:00"
draft = false
tags = ["python", "flask"]
categories = ["python", "flask"]
title = "Flask 应用国际化"
slug = "flask-i18n"
+++

## Babel

> Babel is an integrated collection of utilities that assist in internationalizing and localizing Python applications, with an emphasis on web-based applications.

- 文档：http://babel.pocoo.org/en/latest/
- 代码：https://github.com/python-babel/babel

## Flask-Babel

Flask 的 i18n 扩展，集成 babel、pytz 等。

- 文档：https://pythonhosted.org/Flask-Babel/
- 代码：https://github.com/python-babel/flask-babel

## 使用

- 安装：`pip install Flask-Babel`

- babel 配置文件：babel.cfg

```ini
[python: **.py]
[jinja2: **.html]
extensions=jinja2.ext.autoescape,jinja2.ext.with_,webassets.ext.jinja2.AssetsExtension
```

<!--more-->

- Flask-Babel 配置：

```python
BABEL_DEFAULT_LOCALE = 'zh_CN’                  # locale 选项，默认 'en'
BABEL_DEFAULT_TIMEZONE = 'Asia/Shanghai'        # 时区，默认 'UTC'
BABEL_TRANSLATION_DIRECTORIES = 'translations'  # 翻译文件所在目录，默认 'translations'
```

- 生成翻译文件模版：

```
$ pybabel extract -F babel.cfg -o messages.pot .
```

如果使用了 `lazy_gettext()` 这样的函数，需要在上面的命令行参数指定：

```
$ pybabel extract -F babel.cfg -k lazy_gettext -o messages.pot .
```

- 生成翻译文件:

```
$ pybabel init -i messages.pot -d translations
```

- 编辑 translations/zh_CN/LC_MESSAGES/messages.po 文件，手动翻译。po 文件内容形如：

```
#: forms.py:65 forms.py:78
#: templates/flask_user/emails/invite_child_user_message.html:9
msgid "Username"
msgstr ""
```

其中：
  - `#:` 注释内容是 ‘文件名:行号’，即所有出现过的地方
  - `msgid` 是需要翻译的内容
  - `msgstr` 是翻译后的内容，如果留空，则会显示原文，即 msgid

- 更新翻译文件（一般只需要 init 一次）：

```
$ pybabel update -i messages.pot -d translations
```

- 编译

```
$ pybabel compile -d translations
```

## 工作流

```
$ pybabel extract -F babel.cfg -o messages.pot .
$ pybabel init -i messages.pot -d translations     # 第一次
$ pybabel update -i messages.pot -d translations   # 更新
# 手动翻译
$ pybabel compile -d translations
```
