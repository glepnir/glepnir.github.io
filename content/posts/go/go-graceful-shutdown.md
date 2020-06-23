---
author: "raphael"
title: "Go 的 graceful shutdown"
date: "2020-06-15"
description: "Go 的优雅关闭"
tags: ["Go"]
categories: ["Go"]
---

## 一个简单的 Http 服务

```go
package main

import (
    "log"
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
)

func main() {
    router := gin.Default()
    router.GET("/", func(c *gin.Context) {
        time.Sleep(5 * time.Second)
        c.String(http.StatusOK, "Welcome Gin Server")
    })

    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    // service connections
    if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        log.Fatalf("listen: %s\n", err)
    }

    log.Println("Server exiting")
}
```

上述的代码很简单，但是有个问题如果客户端还在发起请求服务端直接关闭，就会导致丢失数据，如果是一些交易网站
等等包含重要数据的传输就会出现一些问题。Go 在 1.8 添加了一个[shutdown](https://golang.org/doc/go1.8#http_shutdown)
那么使用这个方法就可以实现更优雅的关闭。

## 改进

需要理清楚一些思路才能写好代码，怎么做到优雅的关闭.

- 关闭之后需要确保没有新的使用者连接
- 确保处理完所有的 http 连接才会正常的关闭

```go
// +build go1.8

package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
)

func main() {
    router := gin.Default()
    router.GET("/", func(c *gin.Context) {
        time.Sleep(5 * time.Second)
        c.String(http.StatusOK, "Welcome Gin Server")
    })

    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    go func() {
        // service connections
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("listen: %s\n", err)
        }
    }()

    // Wait for interrupt signal to gracefully shutdown the server with
    // a timeout of 5 seconds.
    quit := make(chan os.Signal, 1)
    // kill (no param) default send syscall.SIGTERM
    // kill -2 is syscall.SIGINT
    // kill -9 is syscall.SIGKILL but can't be catch, so don't need add it
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    log.Println("Shutdown Server ...")

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server Shutdown: ", err)
    }

    log.Println("Server exiting")
}
```

首先可以看到将 srv.ListenAndServe 直接丢到背景执行，这样才不会阻断后续的流程，接着宣告一个 os.Signal 信号的 Channel，并且接受系统 SIGINT 及 SIGTERM，也就是只要通过 kill 或者是 docker rm 就会收到信号关闭 quit 通道

```go
<- quit
```

整个 main 函数运行到这里就会阻塞。channel 的阻塞不了解的需要好好看下 channel 的部分了。假如按下`C-c`
系统信号(SIGINT,SIGTERM) 就会发送值到 quit 那么
quit 就会取到值，那么 main 函数就会继续往下执行了。

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
if err := srv.Shutdown(ctx); err != nil {
    log.Fatal("Server Shutdown: ", err)
}
```

最后可以看到 srv.Shutdown 就是用来处理『1. 关闭连接』及『2. 等待所有连接处理结束』
可以看到传了一个 context 进 Shutdown，目的就是让程式最多等待 5 秒时间，如果超过 5 秒就强制关闭所有连线
所以您需要根据 server 处理的资料时间来决定等待时间，设定太短就会造成强制关闭，建议依照自己的业务来设定
至于服务 shutdown 后可以处理哪些事情就看开发者决定。
