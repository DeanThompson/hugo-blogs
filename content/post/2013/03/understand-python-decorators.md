+++
date = "2013-03-13T00:26:58+08:00"
draft = false
tags = ["python", "decorator", "stackoverflow", "translation"]
categories = ["python"]
title = "【翻译】理解 Python 装饰器"
slug = "understand-python-decorators"
+++

## Note

前段时间在 stack overflow 上看到一个关于 python decorator（装饰器）的问题，有一个人很耐心的写了一篇很长的教程。我也很耐心的看完了，获益匪浅。现在尝试翻译过来，尽量追求准确和尊重原文。不明白的地方，或翻译不好的地方，请参照原文，地址：

> [Understanding Python decorators](http://stackoverflow.com/questions/739654/understanding-python-decorators#answer-1594484)

---

# 1. python的函数是对象（Python's functions are objects）

要理解装饰器，就必须先知道，在python里，函数也是对象（functions are objects）。明白这一点非常重要，让我们通过一个例子来看看为什么。

```python
def shout(word="yes"):
    return word.capitalize()+"!"
 
print shout()
# outputs : 'Yes!'
 
# 作为一个对象，你可以像其他对象一样把函数赋值给其他变量
 
scream = shout
 
# 注意我们没有用括号：我们不是在调用函数，
# 而是把函数'shout'的值绑定到'scream'这个变量上
# 这也意味着你可以通过'scream'这个变量来调用'shout'函数
 
print scream()
# outputs : 'Yes!'
 
# 不仅如此，这也还意味着你可以把原来的名字'shout'删掉，
# 而这个函数仍然可以通过'scream'来访问
del shout
try:
    print shout()
except NameError, e:
    print e
    #outputs: "name 'shout' is not defined"
 
print scream()
outputs: 'Yes!'
```

OK，先记住这点，我们马上会用到。python 函数的另一个有趣的特性是，它们可以在另一个函数体内定义。

```python
def talk():
 
    # 你可以在 'talk' 里动态的(on the fly)定义一个函数...
    def whisper(word="yes"):
        return word.lower()+"..."
 
    # ... 然后马上调用它！
 
    print whisper()
 
# 每当调用'talk'，都会定义一次'whisper'，然后'whisper'在'talk'里被调用
talk()
# outputs:
# "yes..."
 
# 但是"whisper" 在 "talk"外并不存在:
 
try:
    print whisper()
except NameError, e:
    print e
    #outputs : "name 'whisper' is not defined"*
```

<!--more-->

# 2. 函数引用（Functions references）

OK，还在吧？！现在到了有趣的部分，你刚刚已经知道了，python的函数也是对象，因此：

  - 可以被赋值给变量
  - 可以在另一个函数体内定义

那么，这样就意味着一个函数可以返回另一个函数 :-)，来看个例子：

```python
def getTalk(type="shout"):
 
    # 我们先动态定义一些函数
    def shout(word="yes"):
        return word.capitalize()+"!"
 
    def whisper(word="yes") :
        return word.lower()+"...";
 
    # 然后返回其中一个
    if type == "shout":
        # 注意：我们是在返回函数对象，而不是调用函数，
        # 所以不要用到括号 "()"
        return shout 
    else:
        return whisper
 
# 那你改如何使用这个怪兽呢？(How do you use this strange beast?)
 
# 先把函数赋值给一个变量
talk = getTalk()     
 
# 你可以发现 "talk" 其实是一个函数对象:
print talk
#outputs : <function shout at 0xb7ea817c>
 
# 这个对象就是 getTalk 函数返回的:
print talk()
#outputs : Yes!
 
# 你甚至还可以直接这样使用(if you feel wild):
print getTalk("whisper")()
#outputs : yes...
```

但是等等，还有呢。既然可以返回一个函数，那么也就可以像参数一样传递：

```python
def doSomethingBefore(func):
    print "I do something before then I call the function you gave me"
    print func()
 
doSomethingBefore(scream)
#outputs:
#I do something before then I call the function you gave me
#Yes!
```

那好，你现在已经具备了理解装饰器的所有基础知识了。你看，装饰器也就是一种包装材料，**它们可以让你在执行被装饰的函数之前或之后执行其他代码，而且不需要修改函数本身**。（原句比较长：You see, decorators are wrappers which means that they let you execute code before and after the function they decorate without the need to modify the function itself.）

# 3. 手工制作装饰器（Handcrafted decorators）

你可以像这样来定制：

```python
# 一个装饰器是一个需要另一个函数作为参数的函数
def my_shiny_new_decorator(a_function_to_decorate):
 
    # 在装饰器内部动态定义一个函数：wrapper(原意：包装纸).
    # 这个函数将被包装在原始函数的四周
    # 因此就可以在原始函数之前和之后执行一些代码.
    def the_wrapper_around_the_original_function():
 
        # 把想要在调用原始函数前运行的代码放这里
        print "Before the function runs"
 
        # 调用原始函数（需要带括号）
        a_function_to_decorate()
 
        # 把想要在调用原始函数后运行的代码放这里
        print "After the function runs"
 
    # 直到现在，"a_function_to_decorate"还没有执行过 (HAS NEVER BEEN EXECUTED).
    # 我们把刚刚创建的 wrapper 函数返回.
    # wrapper 函数包含了这个函数，还有一些需要提前后之后执行的代码，
    # 可以直接使用了（It's ready to use!）
    return the_wrapper_around_the_original_function
 
# Now imagine you create a function you don't want to ever touch again.
def a_stand_alone_function():
    print "I am a stand alone function, don't you dare modify me"
 
a_stand_alone_function()
#outputs: I am a stand alone function, don't you dare modify me
 
# 现在，你可以装饰一下来修改它的行为.
# 只要简单的把它传递给装饰器，后者能用任何你想要的代码动态的包装
# 而且返回一个可以直接使用的新函数:
 
a_stand_alone_function_decorated = my_shiny_new_decorator(a_stand_alone_function)
a_stand_alone_function_decorated()
#outputs:
#Before the function runs
#I am a stand alone function, don't you dare modify me
#After the function runs
```

现在你大概希望，每次调用 `a_stand_alone_function` 时，实际调用的是 `a_stand_alone_function_decorated` 。这很容易，只要把 `my_shiny_new_decorator` 返回的函数覆盖 `a_stand_alone_function` 就可以了：

```python
a_stand_alone_function = my_shiny_new_decorator(a_stand_alone_function)
a_stand_alone_function()
#outputs:
#Before the function runs
#I am a stand alone function, don't you dare modify me
#After the function runs
 
# And guess what? That's EXACTLY what decorators do!
```

# 4. 揭秘装饰器(Decorators demystified)

我们用装饰器的语法来重写一下前面的例子：

```python
@my_shiny_new_decorator
def another_stand_alone_function():
    print "Leave me alone"
 
another_stand_alone_function() 
#outputs: 
#Before the function runs
#Leave me alone
#After the function runs
```

是的，这就完了，就这么简单。`@decorator` 只是下面这条语句的简写(shortcut)：

```python
another_stand_alone_function = my_shiny_new_decorator(another_stand_alone_function)
```

装饰器其实就是装饰器模式的一个python化的变体（pythonic variant）。为了方便开发，python已经内置了好几种经典的设计模式，比如迭代器（iterators）。
当然，你还可以堆积使用装饰器(you can cumulate decorators)：

```python
def bread(func):
    def wrapper():
        print "</''''''\>"
        func()
        print "<\______/>"
    return wrapper
 
def ingredients(func):
    def wrapper():
        print "#tomatoes#"
        func()
        print "~salad~"
    return wrapper
 
def sandwich(food="--ham--"):
    print food
 
sandwich()
#outputs: --ham--
sandwich = bread(ingredients(sandwich))
sandwich()
#outputs:
#</''''''\>
# #tomatoes#
# --ham--
# ~salad~
#<\______/>
```
    
用python的装饰器语法表示：

```python
@bread
@ingredients
def sandwich(food="--ham--"):
    print food
 
sandwich()
#outputs:
#</''''''\>
# #tomatoes#
# --ham--
# ~salad~
#<\______/>
```

装饰器放置的顺序 **很重要**：

```python
@ingredients
@bread
def strange_sandwich(food="--ham--"):
    print food
 
strange_sandwich()
#outputs:
##tomatoes#
#</''''''\>
# --ham--
#<\______/>
# ~salad~
```

# 5. 回答题主问题，略

# 6. 给装饰器函数传参（Passing arguments to the decorated function）

```python
# 这不是什么黑色魔法(black magic)，你只是必须让wrapper传递参数:
 
def a_decorator_passing_arguments(function_to_decorate):
    def a_wrapper_accepting_arguments(arg1, arg2):
        print "I got args! Look:", arg1, arg2
        function_to_decorate(arg1, arg2)
    return a_wrapper_accepting_arguments
 
# 当你调用装饰器返回的函数式，你就在调用wrapper，而给wrapper的
# 参数传递将会让它把参数传递给要装饰的函数
 
@a_decorator_passing_arguments
def print_full_name(first_name, last_name):
    print "My name is", first_name, last_name
 
print_full_name("Peter", "Venkman")
# outputs:
#I got args! Look: Peter Venkman
#My name is Peter 
```

# 7. 装饰方法（Decorating methods）

Python的一个伟大之处在于：方法和函数几乎是一样的(methods and functions are really the same)，除了方法的第一个参数应该是当前对象的引用(也就是 self)。这也就意味着只要记住把 self 考虑在内，你就可以用同样的方法给方法创建装饰器了：

```python
def method_friendly_decorator(method_to_decorate):
    def wrapper(self, lie):
        lie = lie - 3 # very friendly, decrease age even more :-)
        return method_to_decorate(self, lie)
    return wrapper
 
 
class Lucy(object):
 
    def __init__(self):
        self.age = 32
 
    @method_friendly_decorator
    def sayYourAge(self, lie):
        print "I am %s, what did you think?" % (self.age + lie)
 
l = Lucy()
l.sayYourAge(-3)
#outputs: I am 26, what did you think?
```

当然，如果你想编写一个非常通用的装饰器，可以用来装饰任意函数和方法，你就可以无视具体参数了，直接使用 `*args`, `**kwargs` 就行：

```python
def a_decorator_passing_arbitrary_arguments(function_to_decorate):
    # The wrapper accepts any arguments
    def a_wrapper_accepting_arbitrary_arguments(*args, **kwargs):
        print "Do I have args?:"
        print args
        print kwargs
        # Then you unpack the arguments, here *args, **kwargs
        # If you are not familiar with unpacking, check:
        # http://www.saltycrane.com/blog/2008/01/how-to-use-args-and-kwargs-in-python/
        function_to_decorate(*args, **kwargs)
    return a_wrapper_accepting_arbitrary_arguments
 
@a_decorator_passing_arbitrary_arguments
def function_with_no_argument():
    print "Python is cool, no argument here."
 
function_with_no_argument()
#outputs
#Do I have args?:
#()
#{}
#Python is cool, no argument here.
 
@a_decorator_passing_arbitrary_arguments
def function_with_arguments(a, b, c):
    print a, b, c
 
function_with_arguments(1,2,3)
#outputs
#Do I have args?:
#(1, 2, 3)
#{}
#1 2 3
 
@a_decorator_passing_arbitrary_arguments
def function_with_named_arguments(a, b, c, platypus="Why not ?"):
    print "Do %s, %s and %s like platypus? %s" %\
    (a, b, c, platypus)
 
function_with_named_arguments("Bill", "Linus", "Steve", platypus="Indeed!")
#outputs
#Do I have args ? :
#('Bill', 'Linus', 'Steve')
#{'platypus': 'Indeed!'}
#Do Bill, Linus and Steve like platypus? Indeed!
 
class Mary(object):
 
    def __init__(self):
        self.age = 31
 
    @a_decorator_passing_arbitrary_arguments
    def sayYourAge(self, lie=-3): # You can now add a default value
        print "I am %s, what did you think ?" % (self.age + lie)
 
m = Mary()
m.sayYourAge()
#outputs
# Do I have args?:
#(<__main__.Mary object at 0xb7d303ac>,)
#{}
#I am 28, what did you think?
```

# 8. 给装饰器传参（Passing arguments to the decorator）

太棒了，那么现在对于给装饰器本身传参数，你有什么看法呢？好吧，这样说有点绕，因为装饰器必须接受一个函数作为参数，所以就不能把被装饰的函数的参数，直接传给装饰器（you cannot pass the decorated function arguments directly to the decorator.）

在直奔答案之前，我们先写一个小提示：

```python
# Decorators are ORDINARY functions
def my_decorator(func):
    print "I am a ordinary function"
    def wrapper():
        print "I am function returned by the decorator"
        func()
    return wrapper
 
# Therefore, you can call it without any "@"
 
def lazy_function():
    print "zzzzzzzz"
 
decorated_function = my_decorator(lazy_function)
#outputs: I am a ordinary function
 
# It outputs "I am a ordinary function", because that's just what you do:
# calling a function. Nothing magic.
 
@my_decorator
def lazy_function():
    print "zzzzzzzz"
 
#outputs: I am a ordinary function
```

这完全一样，都是 `my_decorator` 被调用。所以当你使用 `@my_decorator` 时，你在告诉 python 去调用 “被变量 `my_decorator` 标记的” 函数（the function 'labeled by the variable "my_decorator"'）。这很重要，因为你给的这个标签能直接指向装饰器。。。或者其他！让我们开始变得邪恶！（Let's start to be evil!）

```python
def decorator_maker():
 
    print "I make decorators! I am executed only once: "+\
          "when you make me create a decorator."
 
    def my_decorator(func):
 
        print "I am a decorator! I am executed only when you decorate a function."
 
        def wrapped():
            print ("I am the wrapper around the decorated function. "
                  "I am called when you call the decorated function. "
                  "As the wrapper, I return the RESULT of the decorated function.")
            return func()
 
        print "As the decorator, I return the wrapped function."
 
        return wrapped
 
    print "As a decorator maker, I return a decorator"
    return my_decorator
 
# Let's create a decorator. It's just a new function after all.
new_decorator = decorator_maker()      
#outputs:
#I make decorators! I am executed only once: when you make me create a decorator.
#As a decorator maker, I return a decorator
 
# Then we decorate the function
 
def decorated_function():
    print "I am the decorated function."
 
decorated_function = new_decorator(decorated_function)
#outputs:
#I am a decorator! I am executed only when you decorate a function.
#As the decorator, I return the wrapped function
 
# Let's call the function:
decorated_function()
#outputs:
#I am the wrapper around the decorated function. I am called when you call the decorated function.
#As the wrapper, I return the RESULT of the decorated function.
#I am the decorated function.
```

不要感到惊讶，让我们做一件完全一样的事情，只不过跳过了中间变量：

```python
def decorated_function():
    print "I am the decorated function."
decorated_function = decorator_maker()(decorated_function)
#outputs:
#I make decorators! I am executed only once: when you make me create a decorator.
#As a decorator maker, I return a decorator
#I am a decorator! I am executed only when you decorate a function.
#As the decorator, I return the wrapped function.
 
# Finally:
decorated_function()   
#outputs:
#I am the wrapper around the decorated function. I am called when you call the decorated function.
#As the wrapper, I return the RESULT of the decorated function.
#I am the decorated function.
```

再做一次，代码甚至更短：

```python
@decorator_maker()
def decorated_function():
    print "I am the decorated function."
#outputs:
#I make decorators! I am executed only once: when you make me create a decorator.
#As a decorator maker, I return a decorator
#I am a decorator! I am executed only when you decorate a function.
#As the decorator, I return the wrapped function.
 
#Eventually:
decorated_function()   
#outputs:
#I am the wrapper around the decorated function. I am called when you call the decorated function.
#As the wrapper, I return the RESULT of the decorated function.
#I am the decorated function.
```

嘿，看到了吗？我们在用 `@` 语法调用了函数 ：-）
那么回到带参数的装饰器。如果我们能够使用一个函数动态（on the fly）的生成装饰器，那么我们就能把参数传递给那个函数，对吗？

```python
def decorator_maker_with_arguments(decorator_arg1, decorator_arg2):
 
    print "I make decorators! And I accept arguments:", decorator_arg1, decorator_arg2
 
    def my_decorator(func):
        # 在这里能传参数是一个来自闭包的馈赠.
        # 如果你对闭包感到不舒服，你可以直接忽略（you can assume it's ok）,
        # 或者看看这里: http://stackoverflow.com/questions/13857/can-you-explain-closures-as-they-relate-to-python
        print "I am the decorator. Somehow you passed me arguments:", decorator_arg1, decorator_arg2
 
        # 不要把装饰器参数和函数参数搞混了！
        def wrapped(function_arg1, function_arg2) :
            print ("I am the wrapper around the decorated function.\n"
                  "I can access all the variables\n"
                  "\t- from the decorator: {0} {1}\n"
                  "\t- from the function call: {2} {3}\n"
                  "Then I can pass them to the decorated function"
                  .format(decorator_arg1, decorator_arg2,
                          function_arg1, function_arg2))
            return func(function_arg1, function_arg2)
 
        return wrapped
 
    return my_decorator
 
@decorator_maker_with_arguments("Leonard", "Sheldon")
def decorated_function_with_arguments(function_arg1, function_arg2):
    print ("I am the decorated function and only knows about my arguments: {0}"
           " {1}".format(function_arg1, function_arg2))
 
decorated_function_with_arguments("Rajesh", "Howard")
#outputs:
#I make decorators! And I accept arguments: Leonard Sheldon
#I am the decorator. Somehow you passed me arguments: Leonard Sheldon
#I am the wrapper around the decorated function.
#I can access all the variables
#   - from the decorator: Leonard Sheldon
#   - from the function call: Rajesh Howard
#Then I can pass them to the decorated function
#I am the decorated function and only knows about my arguments: Rajesh Howard
```

这就是了，带参数的装饰器。参数也可以设置为变量：

```python
c1 = "Penny"
c2 = "Leslie"
 
@decorator_maker_with_arguments("Leonard", c1)
def decorated_function_with_arguments(function_arg1, function_arg2):
    print ("I am the decorated function and only knows about my arguments:"
           " {0} {1}".format(function_arg1, function_arg2))
 
decorated_function_with_arguments(c2, "Howard")
#outputs:
#I make decorators! And I accept arguments: Leonard Penny
#I am the decorator. Somehow you passed me arguments: Leonard Penny
#I am the wrapper around the decorated function.
#I can access all the variables
#   - from the decorator: Leonard Penny
#   - from the function call: Leslie Howard
#Then I can pass them to the decorated function
#I am the decorated function and only knows about my arguments: Leslie Howard
```

如你所见，你可以给装饰器传递参数，就好像其他任意一个使用了这种把戏的函数一样（you can pass arguments to the decorator like any function using this trick. ）。如果你愿意，甚至可以使用 `*args`, `**kwargs`。但是，记住，装置器只调用一次，仅当python导入这个脚本时。你不能在之后动态的设置参数（You can't dynamically set the arguments afterwards.）。当你执行 `import x` 时，这个函数已经被装饰了，因此你不能修改任何东西。

# 9. 实践：装饰器装饰一个装饰器（Let's practice: a decorator to decorate a decorator）

OK，作为一个福利，我将展示一段能用来创建能接受通用的任意参数的装饰器的代码（I'll give you a snippet to make any decorator accept generically any argument. ）。毕竟，为了能接受参数，我们用了另一个函数来创建我们的装饰器。我们包装了装饰器。在我们刚刚看到的东西里，还有用来包装函数的吗？是的，就是装饰器。让我们给装饰器写一个装饰器来玩玩：

```python
def decorator_with_args(decorator_to_enhance):
    """
    This function is supposed to be used as a decorator.
    It must decorate an other function, that is intended to be used as a decorator.
    Take a cup of coffee.
    It will allow any decorator to accept an arbitrary number of arguments,
    saving you the headache to remember how to do that every time.
    """
 
    # We use the same trick we did to pass arguments
    def decorator_maker(*args, **kwargs):
 
        # We create on the fly a decorator that accepts only a function
        # but keeps the passed arguments from the maker.
        def decorator_wrapper(func):
 
            # We return the result of the original decorator, which, after all,
            # IS JUST AN ORDINARY FUNCTION (which returns a function).
            # Only pitfall: the decorator must have this specific signature or it won't work:
            return decorator_to_enhance(func, *args, **kwargs)
 
        return decorator_wrapper
 
    return decorator_maker
```

它可以像这样使用：

```python
# You create the function you will use as a decorator. And stick a decorator on it :-)
# Don't forget, the signature is "decorator(func, *args, **kwargs)"
@decorator_with_args
def decorated_decorator(func, *args, **kwargs):
    def wrapper(function_arg1, function_arg2):
        print "Decorated with", args, kwargs
        return func(function_arg1, function_arg2)
    return wrapper
 
# Then you decorate the functions you wish with your brand new decorated decorator.
 
@decorated_decorator(42, 404, 1024)
def decorated_function(function_arg1, function_arg2):
    print "Hello", function_arg1, function_arg2
 
decorated_function("Universe and", "everything")
#outputs:
#Decorated with (42, 404, 1024) {}
#Hello Universe and everything
 
# Whoooot!
```

我知道，你上一次有这种感觉，是在听一个人说“在理解递归之前，你必须先理解递归”之后。但是现在，掌握之后，你不觉得很爽吗？

# 10. 装饰器最佳实践（Best practices while using decorators）

  - 装饰器是在 python 2.4 之后才有的，所以先确定你的代码运行时；
  - 记住这点：装饰器降低了函数调用效率；
  - 你不能“解装饰”一个函数（You can not un-decorate a function. ）。有一些能用来创建可以移除的装饰器的方法（There are hacks to create decorators that can be removed），但没人用它们。所以一个函数一旦被装饰了，就结束了（不能改变了）。**For all the code.**
  - 装饰器包装了函数，这使得会难以调试。

Python 2.5 通过提供了一个 `functools` 模块解决了最后一个问题。`functools.wraps` 把任意被包装函数的函数名、模块名和 docstring 拷贝给了 `wrapper`. 有趣的事是，`functools.wraps` 也是一个装饰器：-）

```python
# For debugging, the stacktrace prints you the function __name__
def foo():
    print "foo"
 
print foo.__name__
#outputs: foo
 
# With a decorator, it gets messy   
def bar(func):
    def wrapper():
        print "bar"
        return func()
    return wrapper
 
@bar
def foo():
    print "foo"
 
print foo.__name__
#outputs: wrapper
 
# "functools" can help for that
 
import functools
 
def bar(func):
    # We say that "wrapper", is wrapping "func"
    # and the magic begins
    @functools.wraps(func)
    def wrapper():
        print "bar"
        return func()
    return wrapper
```

# 11. 装饰器如何才能有用（How can the decorators be useful?）

现在问题来了：我能用装饰器来干嘛？看起来很酷也很强大，但是来一个实际例子才更好。好吧，有1000中可能性（Well, there are 1000 possibilities.）。一个典型的用途是，用来扩展一个外部导入的函数（你不能修改）的行为，或者为了调试（你不想修改这个函数，因为只是暂时的）。你也可以用装饰器实现只用一段相同的代码来扩展成几个不同的函数，而且你不需要每次都重写这段代码。这样就是常说的 DRY。比如：

```python
def benchmark(func):
    """
    A decorator that prints the time a function takes
    to execute.
    """
    import time
    def wrapper(*args, **kwargs):
        t = time.clock()
        res = func(*args, **kwargs)
        print func.__name__, time.clock()-t
        return res
    return wrapper
 
 
def logging(func):
    """
    A decorator that logs the activity of the script.
    (it actually just prints it, but it could be logging!)
    """
    def wrapper(*args, **kwargs):
        res = func(*args, **kwargs)
        print func.__name__, args, kwargs
        return res
    return wrapper
 
 
def counter(func):
    """
    A decorator that counts and prints the number of times a function has been executed
    """
    def wrapper(*args, **kwargs):
        wrapper.count = wrapper.count + 1
        res = func(*args, **kwargs)
        print "{0} has been used: {1}x".format(func.__name__, wrapper.count)
        return res
    wrapper.count = 0
    return wrapper
 
@counter
@benchmark
@logging
def reverse_string(string):
    return str(reversed(string))
 
print reverse_string("Able was I ere I saw Elba")
print reverse_string("A man, a plan, a canoe, pasta, heros, rajahs, a coloratura, maps, snipe, percale, macaroni, a gag, a banana bag, a tan, a tag, a banana bag again (or a camel), a crepe, pins, Spam, a rut, a Rolo, cash, a jar, sore hats, a peon, a canal: Panama!")
 
#outputs:
#reverse_string ('Able was I ere I saw Elba',) {}
#wrapper 0.0
#wrapper has been used: 1x
#ablE was I ere I saw elbA
#reverse_string ('A man, a plan, a canoe, pasta, heros, rajahs, a coloratura, maps, snipe, percale, macaroni, a gag, a banana bag, a tan, a tag, a banana bag again (or a camel), a crepe, pins, Spam, a rut, a Rolo, cash, a jar, sore hats, a peon, a canal: Panama!',) {}
#wrapper 0.0
#wrapper has been used: 2x
#!amanaP :lanac a ,noep a ,stah eros ,raj a ,hsac ,oloR a ,tur a ,mapS ,snip ,eperc a ,)lemac a ro( niaga gab ananab a ,gat a ,nat a ,gab ananab a ,gag a ,inoracam ,elacrep ,epins ,spam ,arutaroloc a ,shajar ,soreh ,atsap ,eonac a ,nalp a ,nam A

当然，装饰器的好处就是你可以几乎用来装饰所有东西，而且不要重写。也就是我说的 DRY：（Of course the good thing with decorators is that you can use them right away on almost anything without rewriting. DRY, I said:）

:::python
@counter
@benchmark
@logging
def get_random_futurama_quote():
    import httplib
    conn = httplib.HTTPConnection("slashdot.org:80")
    conn.request("HEAD", "/index.html")
    for key, value in conn.getresponse().getheaders():
        if key.startswith("x-b") or key.startswith("x-f"):
            return value
    return "No, I'm ... doesn't!"
 
print get_random_furturama_quote()
print get_random_furturama_quote()
 
#outputs:
#get_random_futurama_quote () {}
#wrapper 0.02
#wrapper has been used: 1x
#The laws of science be a harsh mistress.
#get_random_futurama_quote () {}
#wrapper 0.01
#wrapper has been used: 2x
#Curse you, merciful Poseidon!
```
    
Python 语言本身也提供了一些装饰器：`property`、`staticmethod` 等。Django 用装饰器来管理换成和视图权限。Twisted 用来伪装 内联异步函数调用（Twisted to fake inlining asynchronous functions calls. ）。这确实是一片广阔的天地。（This really is a large playground.）

