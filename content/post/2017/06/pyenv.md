+++
date = "2017-06-20T15:09:27+08:00"
draft = false
tags = ["python", "devops"]
categories = ["python"]
title = "Pyenv 使用笔记"
slug = "pyenv-notes"
+++

应用使用虚拟环境是每个 Python 程序员都应该要掌握的技能。
[pyenv](https://github.com/pyenv/pyenv) 是一个非常好用的 Python 环境管理工具。有这些主要特性：

1. 方便的安装、管理不同版本的 Python，而且不需要 sudo 权限，不会污染系统的 Python 版本
2. 可以修改当前用户使用的默认 Python 版本
3. 集成 virtualenv，自动安装、激活
4. 命令行自动补全

详细内容见 [Github - pyenv/pyenv](https://github.com/pyenv/pyenv).

## 安装 pyenv

最简单的方式是使用 [pyenv-installer](https://github.com/pyenv/pyenv-installer):

```
curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash
```

然后在 `~/.bashrc` 或 `~/.zshrc` 中添加如下内容：

```bash
export PATH="~/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```

<!--more-->

## 常用命令

完整的命令行列表可以参考 [pyenv/COMMANDS.md](https://github.com/pyenv/pyenv/blob/master/COMMANDS.md).

- 安装 Python

```
pyenv install 3.6.0
```

这个命令会为当前用户下载和安装 3.6.0，安装过程可以使用镜像加速，详见下文。

- 新建虚拟环境

```
pyenv virtualenv 3.6.0 py36
```

- 设置当前路径使用的 Python 环境

```
pyenv local py36
```

这个命令会在当前路径创建一个 `.python-version` 文件，文件内容就是 `py36`，即环境名称。所以一般需要把 `.python-version` 添加到 gitignore.

下次进入该目录时，会自动激活虚拟环境；离开后自动退出。

## 搭建镜像

pyenv 默认从 Python 官网下载安装包，比较慢；也支持镜像网站，可以自己搭建。

### 搭建镜像

其实就是把安装包下载好，放到服务器上，用 Nginx 搭建一个下载服务。但安装包的文件名必须是文件的 SHA256 值。
如 Python-3.6.0.tar.xz 安装包应该保存为 b0c5f904f685e32d9232f7bdcbece9819a892929063b6e385414ad2dd6a23622

1. 创建目录 `/data/pythons`
2. 下载安装包，从 [搜狐的开源镜像](http://mirrors.sohu.com/python/) 下载 `.tar.xz` 格式的安装包。
3. 计算 SHA256（可以使用 `sha256sum` 命令），重命名文件
4. 配置 Nginx

```nginx
server {
    listen 8000;
    root /data/pythons;
    autoindex on;
}
```

如果没有或不想使用 Nginx，也可以用 Python 运行一个简易的 HTTP 服务：

```
python3 -m http.server
```

### 使用镜像

```
export PYTHON_BUILD_MIRROR_URL=http://localhost:8000
pyenv install 3.6.0
```

可以把 `export PYTHON_BUILD_MIRROR_URL=http://localhost:8000` 添加到 `~/.bashrc`.

安装其他版本时，pyenv 会回退到从官网下载。
