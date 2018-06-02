+++
date = "2018-06-02T15:11:15+08:00"
title = "CentOS 7 FirewallD"
draft = false
slug = "centos7-firewalld"
categories = ["devops"]
tags = ["hadoop", "security", "firewall"]
+++

## 背景故事

线上服务器一直没有开启防火墙，没有约束用起来倒也省事。部署 Hadoop 集群（CDH 发行版）的时候，所有网上看过的教程和笔记（包括 CDH 官方文档），全部都提到了部署过程中要关闭防火墙；极少数教程会提到如果有需要，可以在部署完成后再开启；然而没有任何教程在最后真正开启了防火墙。

因为没有防火墙，其实也发生过几次安全事故：

- 某天某台服务器 CPU 利用率很高，后来发现是因为被人利用 rundeck 的漏洞植入了一个挖矿程序；
- 某天有个跑在 Docker 里的 Redis 出现故障，经查也是被植入了挖矿程序
- 某天发现有台机器上有个废弃的 MySQL 跑在公网上，日志里面几乎全是尝试登录的记录

这几次事故虽然没有导致财产损失，但是公网太可怕，没有防火墙就是在外面裸奔，随时可能受到攻击。Hadoop 集群所有服务都是绑定到 `0.0.0.0`，加上没有开启认证，很容易被拖库。

## FirewallD

最先想到的是用 iptables，之前也有使用经历，然而这玩意儿实在太复杂，概念、规则太多，一直没弄懂。CentOS 7 默认安装了 [FirewallD](http://www.firewalld.org/)，使用起来非常方便，也很好理解。网上的介绍和教程很多，不赘述。直接介绍我的使用策略。

FirewallD 有很多种 zone policy，直接使用默认的 `public`.

<!--more-->

首先内网之间必须能相互访问，否则各种集群的节点之间无法通信，会导致集群无法使用。我们有两套内网环境，一个是机房服务器之间，IP 网段是 `172.16.24.0/24`；另一个是本地和服务器之间，通过 openvpn 连接，有两个 IP 段 `10.8.0.0/24` 和 `10.8.1.0/24`. 参考 [这篇文章](http://xuxping.com/2017/04/04/hadoop%E9%9B%86%E7%BE%A4%E6%90%AD%E5%BB%BA%E8%BF%87%E7%A8%8B%E9%97%AE%E9%A2%98%E6%B1%87%E6%80%BB/)进行配置：

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=172.16.24.0/24 accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.8.0.0/24 accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.8.1.0/24 accept'
sudo firewall-cmd  --reload
```

其次常用服务、端口也需要开启：

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=openvpn

sudo firewall-cmd --permanent --add-port=5000
sudo firewall-cmd --permanent --add-port=8080
sudo firewall-cmd --permanent --add-port=8088
sudo firewall-cmd --reload
```

配置完成之后可以查看 `/etc/firewalld/zones/public.xml` 文件进一步确认开启的 service、source 和 port. 挑个端口用 `telnet` 测试：

```bash
> telnet <public-ip> 21050

Trying <public-ip>...
telnet: connect to address <public-ip>: Connection refused
telnet: Unable to connect to remote host

> telnet 172.16.24.123 21050

Trying 172.16.24.123...
Connected to 172.16.24.123.
Escape character is '^]'.
```

## FirewallD & Docker

如果先运行 `dockerd` 再运行 `firewalld`, 会导致 Docker 无法正常工作，用 Docker 部署的程序无法访问了。这个问题在网上有很多讨论，Docker 的 GitHub 主页就有[一个 issue](https://github.com/moby/moby/issues/16137).
我是这么解决的：

```bash
sudo firewall-cmd --permanent --zone=trusted --change-interface=docker0
sudo firewall-cmd --reload
sudo service docker restard
```

也就是把 `docker0` 网卡添加到 `trusted` zone，再重启 `dockerd`. 操作完成后 Docker 服务恢复正常，但是 `firewalld` 进程却意外退出了，大量这种日志：

```text
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t nat -n -L DOCKER' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -n -L DOCKER' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -n -L DOCKER-ISOLATION' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C DOCKER-ISOLATION -j RETURN' failed: iptables: Bad rule (does a matching rule exist in that chain?).
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t nat -C POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t nat -C POSTROUTING -m addrtype --src-type LOCAL -o docker0 -j MASQUERADE' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -D FORWARD -i docker0 -o docker0 -j DROP' failed: iptables: Bad rule (does a matching rule exist in that chain?).
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C FORWARD -i docker0 -o docker0 -j ACCEPT' failed: iptables: Bad rule (does a matching rule exist in that chain?).
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C FORWARD -i docker0 ! -o docker0 -j ACCEPT' failed: iptables: Bad rule (does a matching rule exist in that chain?).
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t nat -C PREROUTING -m addrtype --dst-type LOCAL -j DOCKER' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t nat -C OUTPUT -m addrtype --dst-type LOCAL -j DOCKER' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C FORWARD -o docker0 -j DOCKER' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT' failed: iptables: Bad rule (does a matching rule exist in that chain?).
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -t filter -C FORWARD -j DOCKER-ISOLATION' failed: iptables: No chain/target/match by that name.
ERROR: COMMAND_FAILED: '/sbin/iptables -w2 -D FORWARD -i docker0 -o docker0 -j DROP' failed: iptables: Bad rule (does a matching rule exist in that chain?).
```

参照 [这个](https://github.com/moby/moby/issues/16137#issuecomment-271615192) 和 [这个](https://stackoverflow.com/questions/33600154/docker-not-starting-could-not-delete-the-default-bridge-network-network-bridg/33604859#33604859) 做法均无法消除这种错误日志，但是配置的防火墙规则都生效了。

## Ansible Role

把以上配置写成 Ansible 任务进行自动化：

```yaml
---

- name: stop iptables and disable iptables on boot
  service: name=iptables state=stopped enabled=no
  ignore_errors: true

- name: ensure firewalld installed
  yum: name=firewalld state=present

- name: enable firewalld
  service: name=firewalld state=started enabled=yes

- name: set public as default zone policy
  command: firewall-cmd --set-default-zone=public

- name: ensure private network is not blocked
  firewalld:
    rich_rule: 'rule family=ipv4 source address={{ item }} accept'
    permanent: true
    state: enabled
  with_items:
      - 172.16.24.0/24
      - 10.8.0.0/24
      - 10.8.1.0/24

- name: enable common services
  firewalld:
    service: '{{ item }}'
    permanent: true
    state: enabled
  with_items:
    - http
    - https
    - ssh
    - ntp
    - openvpn

- name: enable ports
  firewalld:
    port: '{{ item }}'
    permanent: true
    state: enabled
  with_items:
    - 58890/tcp
    - 58880/tcp
    - 5000/tcp
    - 8080/tcp
    - 8088/tcp
    - 8888/tcp

- name: enable docker interface
  firewalld:
    zone: trusted
    interface: docker0
    permanent: true
    state: enabled

- name: enable docker ports
  firewalld:
    port: '{{ item }}'
    permanent: true
    state: enabled
  with_items:
    - 4243/tcp

# 有些机器可能没有运行 dockerd，简单的通过 ignore_errors 来跳过
- name: restart docker daemon
  service: name=docker state=restarted
  ignore_errors: true

- name: reload firewalld
  service: name=firewalld state=reloaded

# 有时候会出现 firewalld 进程意外退出的情况，具体原因待查
- name: enable firewalld
  service: name=firewalld state=started enabled=yes
```

## References

- [FirewallD 官网](http://www.firewalld.org/)
- [DigitalOcean: How To Set Up a Firewall Using FirewallD on CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7)
- [Linode: Introduction to FirewallD on CentOS](https://www.linode.com/docs/security/firewalls/introduction-to-firewalld-on-centos/)
- [GitHub: Docker vs. firewalld on CentOS 7 #16137](https://github.com/moby/moby/issues/16137)
- [Ansible firewalld](http://docs.ansible.com/ansible/latest/modules/firewalld_module.html)
