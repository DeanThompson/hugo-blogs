+++
date = "2015-05-24T22:27:49+08:00"
draft = false
slug = "bypass gfw with shadowsocks"
title = "使用 shadowsocks 实现科学上网"
tags = ["shadowsocks", "socks5", "linode", "gfw", "vpn"]
categories = ["shadowsocks", "vpn"]
+++

## 缘起

GFW 早已经是臭名昭著，路人皆知的了，因为它的存在，使得整个大陆的用户都只能在「局域网」里活动。政治敏感的内容就不说了，很多技术性的网站也被墙掉，导致查找问题浏览网页时经常网络被重置。

我是个重度 Google 用户，虽然经常用到的 Google 的产品基本上只有 Google 搜索和 Gmail，但只需要这两项就让我离不开 Google。此外，还有很多网站使用 Google 的 OpenID 登录，引用 Google 的字体文件和其他资源文件，这些网站也都几乎无法正常访问。我曾经使用过一些手段来实现翻墙，在大学时得益于教育网免费的 IPv6，毕业后使用了很久的 GoAgent，手机上用过 [fqrouter](http://fqrouter.com/)，然而都不是很稳定和一劳永逸的解决方案。

有很多人使用 VPN，有购买的，也有自己搭建的。在 GoAgent 无法使用后，我开始正式考虑使用 VPN 了，但不想买 VPN，主要原因有：

1. 很多人使用的 VPN 容易被盯上而面临被干掉的危险（应该是多虑了）
2. 出于信息安全和隐私的考虑，不希望自己的信息有被第三方获取的风险（所以也不想用 fqrouter 了）
3. 想自己折腾

所以就选择了国外 VPS + Shadowsocks 的解决方案。

## 购买 VPS

比较熟悉的是 Linode 和 DigitalOcean，两家的最低配置基本上差不多，但是 Linode 的价格（$10 每月）是后者的两倍。本来是想选择 DigitalOcean 的，但是在家折腾的时候，始终打不开 DigialOcean 的网站。。。于是就选择了 Linode 的 VPS。

注册过程略去不表，选择机房的时候还是需要测试一下的。网上大家都推荐东京的机房，但是我购买的时候没有这个选项，不过亚洲有新加坡的机房。不管怎样，在[这个页面](https://www.linode.com/speedtest) 上做一些测速就知道怎么选了。我测试后发现新加坡的速度最好（物理优势），所以就选择了新加坡的机房；不过也不用担心，如果以后想换到别的机房，也是可以迁移的。

选好机房就可以安装系统了，我选择的是最熟悉方便的 Ubuntu 系统，安装过程非常简单，也很快。启动机器后，可以 SSH 连接上去。

购买的是最低的配置（[https://www.linode.com/pricing](https://www.linode.com/pricing)），不过对于个人应用，尤其是目前只有搭建 VPN 的需求来说，还是很奢侈的了。

## 安装 Shadowsocks

我用的是 Python 实现的版本，安装过程非常简单，文档上也有[教程](https://github.com/shadowsocks/shadowsocks)。

在 VPS 和本机都安装 shadowsocks：

```bash
pip install shadowsocks
```

编写配置文件 shadowsocks.json（把 server 和 password 替换成自己的服务器 IP 和 shadowsocks 服务器的密码）：

```json
{
    "server":"my_server_ip",
    "server_port":8388,
    "local_address": "127.0.0.1",
    "local_port":1080,
    "password":"mypassword",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false
}
```
这份配置文件是客户端和服务端通用的，`local_address` 和 `local_port` 是客户端用的。

在 VPS 上启动 shadowsocks 服务器：

```bash
ssserver -c /path/to/shadowsocks.json
```

在本机启动 shadowsocks 客户端：

```bash
sslocal -c /path/to/shadowsocks.json
```

最终使用的时候，VPN 配置的是本机的 shadowsocks，即 `127.0.0.1:1080`，而不是直接连接服务端版本。

## Chrome 使用 socks 代理

Linux 系统可以配置全局的网络代理，Chrome 可以设置使用系统默认的代理配置，也可以使用 SwitchySharp 做更灵活的配置。

使用过 GoAgent 的人应该都知道 SwitchySharp 这个 Chrome 插件。SwitchySharp 搭配使用 Shadowsocks 也很简单，只需要几步配置就可以实现：

1. 打开 SwitchySharp 的配置界面，新建一个情景模式，命名为 Shadowsocks
2. 详细配置页面，SOCKS 代理一栏，填写 IP `127.0.0.1` 和 端口 `1080`，选择 "SOCKS v5"，然后保存
3. 切换规则页面，把所有规则的情景模式从 GoAgent 改为 Shadowsocks，然后保存
4. 更新在线规则列表，情景模式选择 Shadowsocks；也可以手动添加规则

OK，完成。此后访问规则列表里的网站，都会走 Shadowsocks 的代理。如果使用过 SwitchySharp + GoAgent，即使没有截图，上面的配置很容易理解。

## 命令行使用 socks 代理

浏览器可以自由翻墙了，终端却仍然还在墙内，使用 curl，wget 和 go get 访问墙外资源时依然失败。

Shadowsocks 的 wiki 上提供了[命令行工具使用代理的教程](https://github.com/shadowsocks/shadowsocks/wiki/Using-Shadowsocks-with-Command-Line-Tools)，不过我没有配置成功。后来找了另一个工具：[Privoxy](http://www.privoxy.org/).

Ubuntu 安装 Privoxy 非常简单：

```bash
sudo apt-get install privoxy
```

安装好后会有一个 privoxy 的命令，配置文件在 /etc/privoxy/ 目录下。Privoxy 是个 web 代理工具，提供了非常复杂的配置可以用来实现很强大的功能；不过对于我来说只需要使用一小部分。

编辑 /etc/privoxy/config 文件，在最后添加这几行配置：

```conf
forward-socks5  /               127.0.0.1:1080 .
listen-address  127.0.0.1:8118
# local network do not use proxy
forward         192.168.*.*/    .
forward         10.*.*.*/       .
forward         127.*.*.*/      .
```

`forward-socks5` 这一行表示所有网络通过 socks5 代理，代理服务器是 `127.0.0.1:1080`，即在本机启动的 Shadowsocks 客户端服务。最后三行是本地局域网不使用代理的配置。

重启一下 privoxy：

```bash
sudo service privoxy restart
```

现在就可以在命令行里愉快的上网了，用 go get 安装各种 golang package 都非常顺利。

## Android 手机使用 socks 代理

Shadowsocks 真心人类的希望，还提供了 Android 的客户端：[https://github.com/shadowsocks/shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)，安装和配置过程都很简单，略去不表。

## 后记

经过上面的一番折腾，基本上实现了全平台的翻墙上网，这种自由进出的感觉不是一般的舒畅。同时也感到一丝悲哀，本来很自然的东西，在这里却需要想方设法曲线救国才能得到。

感谢 Shadowsocks 的作者们，编写了一个简单而强大的代理工具，造福于民。
