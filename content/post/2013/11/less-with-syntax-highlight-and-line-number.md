+++
date = "2013-11-03T00:30:00+08:00"
draft = false
tags = ["shell", "linux", "command"]
categories = ["linux"]
title = "less 命令支持语法高亮和行号"
slug = "less-with-syntax-highlight-and-line-number"
+++

首先来一句装X的话：

> less is more

# 1. How

less 是一个很方便的命令行工具，但不足的是不能语法高亮，查看的都是黑白的纯文本。幸运的是，[source-highlight](http://www.gnu.org/software/src-highlite/) 可以弥补这一点。在 Ubuntu 安装 source-highlight 非常方便：

```bash
sudo apt-get install source-highlight
```

安装完成后需要做一些简单的配置。编辑 .bashrc，加上以下配置项：

```bash
# less hightlight
export LESSOPEN="| /usr/share/source-highlight/src-hilite-lesspipe.sh %s"
export LESS=" -R "
```

要注意的是 `/usr/share/source-highlight/src-hilite-lesspipe.sh` 是 `src-hilite-lesspipe.sh` 脚本的路径，不同的系统可能不一样，可以查找一下（`find / -name src-hilite-lesspipe.sh`）。

使配置生效：

```bash
source ~/.bashrc
```

这样就可以在之后使用 `less filename` 查看文件内容时，支持语法高亮。

<!--more-->

# 2. Why

接下来看看到底发生了什么事情，可以做到这么「神奇」的效果。

## 2.1. LESSOPEN

首先来看`source-highlight`，这个工具可以根据给定的源文件，读取动态读取语言特性，然后输出一个语法高亮的文件，支持多种输出格式，如 HTML、XHTML、LATEX、 「ANSI _color escape sequences_ 」等；默认是 HTML格式。最后一种输出格式是 ANSI 颜色转义序列，支持彩色。这种输出格式恰好可以和 less 结合使用，使其输出结果支持语法高亮。

再看 `LESSOPEN`。查看 less 的 man 帮助手册，可以看到 less 支持一个叫 「input preprocessor」的东西，可以在 less 打开源文件之前对源文件进行一次预处理。这个「input preprocessor」 可以自己定义：

> To  set up an input preprocessor, set the LESSOPEN environment variable to a command line which will invoke your input preprocessor.  This command line should include one occurrence of the string "%s", which will be replaced by the  filename  when  the input preprocessor command is invoked.

上面这句话说明了如何使用自己定义的预处理器，就是设置一下 `LESSOPEN` 这个环境变量。那么 `LESSOPEN` 到底是什么呢？ 可以在帮助手册找到定义：

> Command line to invoke the (optional) input-preprocessor.

`LESSOPEN` 指定一个「input preprocessor」，后面用 `%s` 读取文件路径。可以看到上面的配置中，有一个前导的竖线 `|`。熟悉 `*nix` 命令行的人知道这是管道，这个竖线表示把「input preprocessor」的处理结果写到标准输出（standard output），然后 less 通过 input pipe 读取再显示到屏幕上。

## 2.2. LESS

另一个变量是 `LESS`，同样查看帮助手册：

> Options which are passed to less automatically.

也就是自动传给 less 的选项，相当于缺省参数。上面设置的缺省选项是 `-R`，看看 `-R` 选项的意义：

> -R or --RAW-CONTROL-CHARS

> Like -r, but only ANSI "color" escape sequences are output in "raw" form. ...

这个选项的意义是，对于「ANSI _color escape sequences_ 」是直接输出的，而不错其他处理。上面用 `source-highlight` 提供的 src-hilite-lesspipe.sh 脚本用作 「input preprocessor」把源文件进行了高亮处理，并且输出「ANSI _color escape sequences_ 」格式，这里设置 `-R` 选项刚好可以把这个高亮过后的字符序列直接输出，因此就可以看到 less 下的语法高亮。

# 3. More...

在第二节里说到 `LESS` 这个环境变量，同理，可以设置其他默认选项，比如 `-N`。`-N` 选项的意义相对更为显然：

> -N or --LINE-NUMBERS

> Causes a line number to be displayed at the beginning of each line in the display.

就是在每一行开头显示行号。这个非常有用啊～于是只要修改一下配置：

```bash
export LESS=" -R -N "
```

这样一来，就可以在 less 时既能语法高亮，还能查看行号，感觉很不错的说。试着贴一张效果图看看。

![less-with-syntax-highlight-and-line-number](http://ww3.sinaimg.cn/large/65df5320tw1ea3o9tmdirj20ch0alq3h.jpg)

# 4. References

- GNU Source-highlight: [http://www.gnu.org/software/src-highlite/](http://www.gnu.org/software/src-highlite/)
- Powering Less to Highlight Syntax and Display Line Numbers:  [http://greyblake.com/blog/2011/09/23/powering-less-to-highlight-syntax-and-display-line-numbers/](http://greyblake.com/blog/2011/09/23/powering-less-to-highlight-syntax-and-display-line-numbers/)

