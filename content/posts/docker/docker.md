+++
title = "Docker入门"
author = "Raphael Huan"
date = "2020-08-25T22:06:20+08:00"
description = "docker"
categories = ["docker"]
tags = ["docker"]
images = [""]
+++

## 什么是Docker
建议google百度更详细。

### 安装Docker

- CentOS

```Shell
yum -y install yum-utils device-mapper-persistent-data lvm2
yum makecache fast
yum -y install docker-ce
```

- Mac 安装Docker for Mac即可

### 镜像加速

- CentOS
```Shell
默认下载Docker会去国外服务器下载，速度较慢，可以设置为阿里云镜像源，速度更快
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```
- Mac
```shell
登陆到阿里云找到镜像中心/镜像加速器会看到属于你自己的镜像加速器地址
https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors

一般长这个样子
https://xxxxx.mirror.aliyuncs.com
将这个地址填写到docker的Preference的Docker Engine里 json的文件格式
{
  "debug": true,
  "experimental": false,
  "registry-mirrors": [
    "https://xxxx.mirror.aliyuncs.com"
  ]
}
然后重启Docker
```

### 启动docker
完成上面的操作已经简单的配置好了docker.启动docker

```sh
安装成功后，需要手动启动，设置为开机启动，并测试一下 Docker
#启动docker服务
systemctl start docker
#设置开机自动启动
systemctl enable docker

Mac 直接省略上面打开docker客户端设置开机启动，当然你可以使用brew
services的方式如果你使用brew cask安装的docker
#测试
docker run hello-world
```

### Docker的仓库
```shell
1.Docker官方的中央仓库设置镜像加速后速度就不会很慢推荐使用
https://hub.docker.com/
2.国内的镜像网站：网易蜂巢，daoCloud等，下载速度快，但是镜像相对不全
https://c.163yun.com/hub#/home
http://hub.daocloud.io/
3.在公司内部会采用私服的方式拉取镜像（添加配置）一般都是用linux做服务器
#需要创建 /etc/docker/daemon.json，并添加如下内容
{
	"registry-mirrors":["https://registry.docker-cn.com"],
	"insecure-registries":["ip:port"]
}
#重启两个服务
systemctl daemon-reload
systemctl restart docker
```
### 镜像的操作

- 拉取镜像
```shell
从中央仓库拉取镜像到本地 一般不填tag会拉去最新的也就是latest
docker pull 镜像名称[:tag]
例如 docker pull mongo
```
- 查看本地镜像
```shell
docker images

你会看到这样的输出
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
mongo               latest              409c3f937574        5 days ago          493MB
hello-world         latest              bf756fb1ae65        7 months ago        13.3kB
```
- 删除镜像

```shell
#很好记rm 一般*nix的删除前缀 i就是image的i
docker rmi ID

例如删除mongo
docker rmi 409c3f937574
```
- 镜像的导入导出
```shell
如果因为网络原因可以通过硬盘的方式传输镜像，虽然不规范，但是有效，但是这种方式导出的镜像名称和版本都是null，需要手动修改
#将本地的镜像导出
docker save -o 导出的路径 镜像id
#加载本地的镜像文件
docker load -i 镜像文件
#修改镜像文件
docker tag 镜像id 新镜像名称：版本

例如打包mongo镜像记得想创建你要导出的文件夹
docker save -o ~/dockerimage/mongo 409c3f937574
加载本地镜像
docker load -i ~/dockerimage/mongo
然后docker images 查看一下
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
<none>              <none>              409c3f937574        5 days ago          493MB
hello-world         latest              bf756fb1ae65        7 months ago        13.3kB
这个none 就是加载的已经打包到本地的mongo ID大小都是一样的
改个name和tag none鬼知道是什么 40是ID的简写如果确保40是唯一
可以这么写如果多个40开头记得多写几个或者写全
docker tag 40 mongo:latest
再用docker images查看一下 这样就顺眼了
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
mongo               latest              409c3f937574        5 days ago          493MB
hello-world         latest              bf756fb1ae65        7 months ago        13.3kB
```
### 容器操作
- 运行容器
```shell
运行容器需要定制具体镜像，如果镜像不存在，会直接下载
#简单操作
docker run 镜像的标识|镜像的名称[:tag]
#常用的参数
docker run -d -p 宿主机端口:容器端口 --name 容器名称 镜像的标识|镜像名称[:tag]
#-d:代表后台运行容器
#-p 宿主机端口:容器端口：为了映射当前Linux的端口和容器的端口
#--name 容器名称:指定容器的名称
```
- 查看容器
```shell
查看全部正在运行的容器信息
docker ps [-qa]
#-a 查看全部的容器，包括没有运行
#-q 只查看容器的标识

会有这样的输出 当前容器的id
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
d00f6136b0d7        bf                  "/hello"            5 seconds ago       Exited (0) 4 seconds ago                       hopeful_poitras
```
- 查看容器日志
```shell
查看容器日志，以查看容器运行的信息
docker logs -f 容器id
#-f：可以滚动查看日志的最后几行
```
- 进入容器的内部
```shell
可以进入容器的内部进行操作，例如进入容器内部的bash命令行
exec是execute的简写执行的意思。记住单词也就记住了。
docker exec -it 容器id bash
```

- 重启&启动&停止&删除容器
```shell
容器的启动，停止，删除等操作，后续会经常使用到
#重新启动容器
docker restart 容器id
#启动停止运行的容器
docker start 容器id

#停止指定的容器(删除容器前，需要先停止容器)
docker stop 容器id
#停止全部容器
docker stop $(docker ps -qa)
#删除指定容器
docker rm 容器id
#删除全部容器
docker rm $(docker ps -qa)

#例如删除hello-world容器首先停止容器
docker ps -a 查看到ID
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
d00f6136b0d7        bf                  "/hello"            5 seconds ago       Exited (0) 4 seconds ago                       hopeful_poitras
#停止容器
docker stop d00
#删除容器
docker rm d00
#查看一下
docker ps -a 没有了hello-world
#然后就可以删除掉hello-world镜像
docker rmi hello-wolrd的id即可
#再用docker images查看一下
#没有了hello-world的镜像
```
### 启动mysql

```shell
#例如docker运行mysql
➜ docker pull mysql
#查看镜像
➜ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
mysql               latest              0d64f46acfd1        3 weeks ago         544MB
#后台运行容器 -e 加上初始化的root密码
➜ docker run -d -p 3309:3306 -e MYSQL_ROOT_PASSWORD=123456   --name mysql 0d                                                                                                                     30%  2.65G ─╯
d20bfc8e2eaf35773a911a8e5e3af8b1bce024a16e7687000d9ef476c4fc3f0e
# 查看当前的容器
➜ docker ps -a                                                                                                                                                                                   30%  2.65G ─╯
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                               NAMES
d20bfc8e2eaf        0d                  "docker-entrypoint.s…"   3 seconds ago       Up 3 seconds        33060/tcp, 0.0.0.0:3309->3306/tcp   mysql
# 进入容器的内部shell环境连接mysqlclient
➜ docker exec -it mysql bash                                                                                                                                                                     30%  2.54G ─╯
root@d20bfc8e2eaf:/# mysql -u root -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 10
Server version: 8.0.21 MySQL Community Server - GPL

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>

#成功运行了mysql
# 退出mysql
mysql> \q
# 退出容器
root@d20bfc8e2eaf:/# exit
```
go中使用docker的mysql
```go
func main() {
	ConnectSQL("localhost", "3309", "root", "123456", "mysql")
}

// ConnectSQL ...
func ConnectSQL(host, port, uname, pass, dbname string) {
	dbSource := fmt.Sprintf(
		"root:%s@tcp(%s:%s)/%s?charset=utf8",
		pass,
		host,
		port,
		dbname,
	)
	d, err := sql.Open("mysql", dbSource)
	if err != nil {
		panic(err)
	}
	err = d.Ping()
	if err != nil {
		panic(err)
	}
	fmt.Println("Connection success")
}
```

极大的改善了开发体验，你可以简单有快速的安装不同版本和不同类型的数据库。

### 数据卷
为什么要用数据卷因为镜像往往都是很纯净的甚至都没有vi，还需要去下载一个vi才能使用。如果使用docker部署不推荐在容器内部维护项目。

数据卷：将宿主机的一个目录映射到容器的一个目录中。可以在宿主机中操作目录中的内容，那么容器内部映射的文件，也会跟着一起改变。

- 创建数据卷
```sh
#创建数据卷后，默认会存放在一个目录下/var/lib/docker/volumes/数据卷名称/_data
# Mac 下的目录~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/tty
docker volume create 数据卷名称

#创建一个go微服务数据卷
➜ docker volume create go-microservices
go-microservices
# 查看数据卷
➜ docker volume ls
DRIVER              VOLUME NAME
local               3e1a82bbf69dc086edf161d5f5737c108d82f04a1c07fa24be77a48d6f7bd0de
local               55f0f0294ae7096d461ffc0319c8e52064856d18ce9ceb194794d39420b2c76a
local               460487207e610918020e8435d071e6127c98f33eb0292433a38a8c8bedaf4f38
local               dd189a79766f32b8da90ff16a7cc4bf97ef662fcd9387e322232cd60de791a36
local               go-microservices
```

- 查看数据卷
```sh
#查看全部数据卷信息
docker volume ls
#查看数据卷的详细信息，可以查询到存放的路径，创建时间等等
docker volume inspect 数据卷名称
``
- 删除数据卷
```sh
#删除指定的数据卷
docker volume rm 数据卷名称
```
- 容器映射数据卷
```sh
#通过数据卷名称映射，如果数据卷不存在。Docker会帮你自动创建，会将容器内部自带的文件，存储在默认的存放路径中。
docker run -v 数据卷名称:容器内部的路径 镜像id

#通过路径映射数据卷，直接指定一个路径作为数据卷的存放位置。但是这个路径下是空的。手动添加内容，推荐这种方式
docker run -v 路径(/root/自己创建的文件夹):容器内部的路径 镜像id
```

### Dockerfile自定义镜像
```sh
创建自定义镜像就需要创建一个Dockerfiler,如下为Dockerfile的语言

from：指定当前自定义镜像依赖的环境
copy：将相对路径下的内容复制到自定义镜像中
workdir：声明镜像的默认工作目录
run：执行的命令，可以编写多个
cmd：需要执行的命令（在workdir下执行的，cmd可以写多个，只以最后一个为准）

```
### 生成镜像
```sh
#编写完Dockerfile后需要通过命令将其制作为镜像，并且要在Dockerfile的当前目录下，之后即可在镜像中查看到指定的镜像信息
# 点意味着生成在当前目录下
docker build -t 镜像名称[:tag] .
```

### DockerCompose

以上面的方式运行一个容器需要添加许多参数。为了更加的方便使用Docker-Compose编写配置文件把参数写进去。
Docker-Compose也可以批量的管理容器所以你只需要编写并维护一个docker-compose.yaml文件即可
地址
[docker-compose](https://github.com/docker/compose),可以在github的release下载已经打包好的
mac下就直接brew装即可
```sh
➜ brew info docker-compose                                                                                                                                                                       30%  2.99G ─╯
docker-compose: stable 1.26.2 (bottled), HEAD
Isolated development environments using Docker
https://docs.docker.com/compose/
Not installed
From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/docker-compose.rb
License: Apache-2.0
==> Dependencies
Required: libyaml ✔, python@3.8 ✔
==> Options
--HEAD
        Install HEAD version
==> Analytics
install: 11,808 (30 days), 41,559 (90 days), 159,035 (365 days)
install-on-request: 11,689 (30 days), 40,917 (90 days), 155,728 (365 days)
build-error: 0 (30 days)
➜ brew install docker-compose
```
但是你也要熟悉linux下的操作。linux下
```sh
#下载好docker-compose然后将DockerCompose文件的名称修改一下，给予DockerCompose文件一个可执行的权限
mv docker-compose-Linux-x86_64 docker-compose
chmod 777 docker-compose
#方便后期操作，配置一个环境变量
#将docker-compose文件移动到了/usr/local/bin，修改了/etc/profile文件，给/usr/local/bin配置到了PATH中

mv docker-compose /usr/local/bin
vi /etc/profile
#添加内容：export PATH=/usr/local/bin:$PATH
source /etc/profile
#测试
docker-compose -v
```

### DockerCompose 管理
编写docker-compose.yml文件yml文件以key:value方式来指定配置信息
多个配置信息以换行+缩进的方式来区分在docker-compose.yml文件中，不要使用制表符

```yaml
version: '3.1'
services:
  mysql:           # 服务的名称
    restart: always   # 代表只要docker启动，那么这个容器就跟着一起启动
    image: daocloud.io/library/mysql:5.7.4  # 指定镜像路径
    container_name: mysql  # 指定容器名称 docker ps 看到的名称
    ports:
      - 3309:3306   #  指定端口号的映射
    environment:
      MYSQL_ROOT_PASSWORD: root   # 指定MySQL的ROOT用户登录密码
      TZ: Asia/Shanghai        # 指定时区
    volumes:
     - ~/docker_mysql/mysql_data:/var/lib/mysql   # 映射数据卷
  go:
    restart: always
    image: go:1.14.7
    container_name: go
    ports:
      - 8080:8080
    environment:
      TZ: Asia/Shanghai
    volumes:
      #填数据卷
  #如果还有镜像容器可以一直往下写
```

### DockerCompose 命令
```sh
在使用docker-compose的命令时，默认会在当前目录下找docker-compose.yml文件
 
#1.基于docker-compose.yml启动管理的容器
docker-compose up -d
 
#2.关闭并删除容器
docker-compose down
 
#3.开启|关闭|重启已经存在的由docker-compose维护的容器
docker-compose start|stop|restart
 
#4.查看由docker-compose管理的容器
docker-compose ps
 
#5.查看日志
docker-compose logs -f
```

### DockerCompos配合Dockerfile一起使用
docker-compose配合Dockerfile使用，就可以使用docker-compose管理自定义的镜像，它会帮你build然后启动。更加方便

```yaml
version: '3.1'
services:
  ssm:
    restart: always
    build:            # 构建自定义镜像
      context: ../      # 指定dockerfile文件的所在路径
      dockerfile: Dockerfile   # 指定Dockerfile文件名称
    image: your_image_name:1.0.1 #指定你镜像的名称和版本
    container_name: 容器名称
    ports:
      - 8081:8080
    environment:
      TZ: Asia/Shanghai
```
运行
```sh
#可以直接基于docker-compose.yml以及Dockerfile文件构建的自定义镜像
docker-compose up -d
# 如果自定义镜像不存在，会自动构建出自定义镜像，如果自定义镜像已经存在，会直接运行这个自定义镜像
#重新构建自定义镜像
docker-compose build
#运行当前内容，并重新构建
docker-compose up -d --build
```
