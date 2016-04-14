+++
date = "2016-04-14T15:33:52+08:00"
draft = false
tags = ["nginx", "aws"]
categories = ["nginx"]
title = "Nginx AWS ELB 域名解析"
slug = "nginx-aws-elb-name-resolution"
+++

最近生产环境上出现了一个奇怪的问题。某日下午，APP 向某个域名发出的所有请求没有响应，服务端也没收到请求；而向另一个域名的请求却没有问题。先记录一下背景：

- 两个域名：api.example.com, web.example.com
- 环境：AWS + ELB + Nginx
- 后端：Python + Django + Gunicorn

出问题的是 api.example.com （下文简称 API）这个域名，所以 web.example.com 就不细说。由于一些历史原因，API 的请求链路大概是这样：

```
                      proxy_pass         backends                      proxy_pass
APP -----> API Nginx -------------> ELB -----------> Backend Nginx(s) ------------> Gunicorn(s)
```

其中 API 的 Nginx 配置大概是这样：

```nginx
location /test {
    proxy_pass http://name.of.elb.aws.com;
}
```

<!--more-->

文章开头描述的现象就是，在 API 的 Nginx 能看到 access log，但是 Backend 的 Nginx 没有接收到请求。所以问题可能出在代理这一步。奇怪的地方在于，刚上线时一切正常，运行了一段时间后才突然出现。猜测有可能是 DNS 解析的问题，但没有根据，也不知道如何解决。

后来 Google 了一番，发现确实是 DNS 的问题。Nginx 会在启动的时候进行域名查找，然后把 IP 地址缓存起来，后续就直接使用这些 IP 地址。而 AWS 的 ELB 所指向的 IP 地址是不固定的，会经常更新；所以这会导致 Nginx 缓存的 IP 地址实际上已经失效。定位出了问题，也参考网上的做法，把 API 的 Nginx 配置稍作修改：

```nginx
location /test {
    resolver 233.5.5.5 valid=30s;
    proxy_pass http://name.of.elb.aws.com;
}
```

其中 [resolver](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver) 就是 Nginx 用于把域名转换为 IP 地址的域名服务器。后面的第一个参数是域名服务器，valid 指定了缓存有效期，这里是 30s （默认 5min）. 加上这个配置后，Nginx 会用指定的域名服务器来解析域名，并定期把缓存失效。这样就能避免 ELB 地址更新带来的问题。

刚开始以为只需要加上 resolver 这一行配置就可以，后来看 [这个 serverfault 上的回答]([http://serverfault.com/a/562518/192152)，还需要把 proxy_pass 的地址定义成一个变量。于是最终的配置变成了：

```nginx
location /test {
    resolver 233.5.5.5 valid=30s;
    set $backends "http://name.of.elb.aws.com";
    proxy_pass $backends;
}
```

修改配置，reload，一两天后如果无响应的现象不再出现，说明问题已经解决。

参考材料：

- [Nginx 文档](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)
- [Nginx with dynamic upstreams](http://tenzer.dk/nginx-with-dynamic-upstreams/)
- [nginx AWS ELB name resolution with resolvers](http://gc-taylor.com/blog/2011/11/10/nginx-aws-elb-name-resolution-resolvers)
- [serverfault - Some nginx reverse proxy configs stops working once a day](http://serverfault.com/questions/560632/some-nginx-reverse-proxy-configs-stops-working-once-a-day)
