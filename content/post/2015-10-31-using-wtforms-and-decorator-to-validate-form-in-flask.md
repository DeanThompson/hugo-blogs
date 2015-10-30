+++
date = "2015-10-31T01:46:10+08:00"
draft = false
tags = ["python", "flask", "decorator", "wtforms"]
categories = ["python", "flask"]
title = "用 WTForms 和装饰器做表单校验"
slug = "using-wtforms-and-decorator-to-validate-form-in-flask"
+++

在一个 Web 应用里，不管是为了业务逻辑的正确性，还是系统安全性，做好参数（querystring, form, json）验证都是非常必要的。

[WTForms](https://github.com/wtforms/wtforms) 是一个非常好用而且强大的表单校验和渲染的库，提供 Form 基类用于定义表单结构（类似 ORM），内置了丰富的字段类型和校验方法，可以很方便的用来做校验。如果应用需要输出 HTML，集成到模板里也很容易。对于 JSON  API 应用，用不到渲染的功能，但是结构化的表单和校验功能依然非常有用。

<!--more-->

以一个注册的应用场景为例，用户输入用户名、邮箱、密码、确认密码，服务程序先检查参数然后处理登录逻辑。这几个字段都是必填的，此外还有一些额外的限制：

- 用户名：长度在 3-20 之间
- 邮箱：合法的邮箱格式，比如 "abc" 就不合法
- 密码：长度在 8-20 之间，必须同时包含大小写字母
- 确认密码：必须与密码一致

如果参数不合法，返回 400；登录逻辑略去不表。

最原始的做法，就是直接在注册的接口里取出每个参数，逐个手动校验。这种做法可能的代码是：

```python
@app.route('/user/signup/', methods=['POST'])
def register():
    username = request.form.get('username')
    if not username or not (3 <= len(username) <= 20):
        abort(400)
    
    email = request.form.get('email')
    if not email or not re.match(EMAIL_REGEX, email):
        abort(400)
    
    password = request.form.get('password')
    if not password:
        abort(400)
    if password == password.lower() or password == password.upper():
        abort(400)
    
    confirm_password = request.form.get('confirm_password')
    if not confirm_password or confirm_password != password:
        abort(400)
    
    # 处理注册的逻辑
```

有可能是我的写法不太对，但是这样检查参数的合法性，实在不够优雅。检查参数的代码行数甚至超出了注册的逻辑，也有些喧宾夺主的感觉。可以把这些代码移出来，使得业务逻辑代码更加清晰一点。下面先用 WTForms 来改造一下。

```python
from wtforms import Form
from wtforms.fields import StringField, PasswordField
from wtforms.validators import DataRequired, Email, Length, EqualTo, ValidationError


class SignupForm(Form):
    username = StringField(validators=[DataRequired(), Length(3, 20)])
    email = StringField(validators=[DataRequired(), Email()])
    password = PasswordField(validators=[DataRequired()])
    confirm_password = PasswordField(validators=[DataRequired(), EqualTo('password')])
    
    def validate_password(self, field):
        password = field.data
        if password == password.lower() or password == passowrd.upper():
            raise ValidationError(u'必须同时包含大小写字母')


@app.route('/user/signup/', methods=['POST'])
def register():
    form = SignupForm(formdata=request.form)
    if not form.validate():
        abort(400)
    
    # 处理注册逻辑，参数从 form 对象获取，比如
    username = form.username.data
```

这个版本带来的好处很明显：

1. 参数更加结构化了，所有字段名和类型一目了然
2. 有内置的，语义清晰的校验方法，可以组合使用
3. 还能自定义额外的校验方法，方法签名是 `def validate_xx(self, field)`，其中 `xx` 是字段名，通过 `field.data` 来获取输入的值
4. 还有没体现出来的，就是丰富的错误提示信息，既有内置的，也可以自定义

再看原来的 `register` 方法，代码变得更加简洁和清晰，整体的编码质量也得到了提升。

那么再考虑一下更复杂的场景，在一个返回 JSON 的 API 应用里，有很多 API，有不同的参数提交方式（GET 方法通过 query string，POST 方法可能有 form 和 JSON），一样的校验错误处理方式（abort(400) 或其他）。我们依然可以像上面那样处理，但如果再借助装饰器改进一下，又能少写几行“重复”的代码。

需要注意的是，WTForms 的 formdata 支持的是类似 Werkzeug/Django/WebOb 中的 `MultiDict` 的数据结构。Flask 中的 `request.json` 是一个 `dict` 类型，所以需要先包装一下。

继续改造注册的例子：

```python
import functools

from werkzeug.datastructures import MultiDict


def validate_form(form_class):
    def decorator(view_func):
        @functools.wraps(view_func)
        def inner(*args, **kwargs):
            if request.method == 'GET':
                formdata = request.args
            else:
                if request.json:
                    formdata = MultiDict(request.json)
                else:
                    formdata = request.form
                    
            form = form_class(formdata=formdata)
            if not form.validate():
                return jsonify(code=400, message=form.errors), 400

            g.form = form
            return view_func(*args, **kwargs)

        return inner

    return decorator


@app.route('/user/signup/', methods=['POST'])
@validate_form(form_class=SignupForm)
def register():
    form = g.form   # 运行到这里，说明表单是合法的

    # 处理注册逻辑，参数从 form 对象获取，比如
    username = form.username.data
```

实现了一个叫 `validate_form` 的装饰器，指定一个 Form 类，处理统一的参数获取、校验和错误处理，如果一切正确，再把 Form 对象保存到全局变量 `g` 里面，这样就可以在 view 函数里取出来用了。现在的 `register` 方法变得更加简洁，甚至都看不到检查参数的那些代码，只需要关心具体的和注册相关的逻辑本身就好。

这个装饰器的可重用性非常好，其他的接口只要定义一个 Form 类，然后调用一下装饰器，再从 `g` 获取 Form 对象。不仅省了很多心思和体力劳动，代码也变得更加清晰优雅和 Pythonic.
