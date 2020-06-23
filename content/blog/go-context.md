+++
author = "raphael"
title = "Go 如何在http中使用context包"
date = "2020-06-23"
description = "Simple Go http request context example"
tags = ["Go"]
categories = ["Go"]
+++

## 简单的 Go http 请求使用 context 包的例子

## Intro

For the longest time I have wanted to see an easy to understand example (read newbie) of how to add data to the “new” golang 1.7 request context object. Since I wasted more than 2 days looking for something like that and never really found anything I decided to figure it out from the docs and write something up for others like me that wanted something simple. The example below is trivial and does not put anything useful in the context it’s just there to get your own juices flowing.

Let’s start with the main function that will really only create the router and the routes.

```go
func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/", StatusPage)
	mux.HandleFunc("/login", LoginPage)
	mux.HandleFunc("/logout", LogoutPage)

	log.Println("Start server on port :8085")
	log.Fatal(http.ListenAndServe(":8085", mux))
 }
```

Our example will allow you to login and logout and once logged in we will put a “hardcoded” username in the context to flow to the StatusPage handler. So this is 3 routes:

- /login
- /logout
- /

Login and Logout are simply done by visiting the route where we add and remove a cookie. Now to cerate the skeletons of the 3 handlers:

```go
func StatusPage(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("This Page will show the context username once the context is added."))

}

func LoginPage(w http.ResponseWriter, r *http.Request) {
	expiration := time.Now().Add(365 * 24 * time.Hour)  ////Set to expire in 1 year
	cookie := http.Cookie{Name: "username", Value: "alice_cooper@gmail.com", Expires: expiration}
	http.SetCookie(w, &cookie)
}


func LogoutPage(w http.ResponseWriter, r *http.Request) {
	expiration := time.Now().AddDate(0, 0, -1)	//Set to expire in the past
	cookie := http.Cookie{Name: "username", Value: "alice_cooper@gmail.com", Expires: expiration}
	http.SetCookie(w, &cookie)
}
```

Now the fun part to add context to the requests… First we’ll need to create middleware and use it in the router. Middleware is simply a function that accepts an http handler and returns an http.handler. In this simple example I will call the middleware component “AddContext” and in the returned handler I will first check to make sure we are logged by looking for the login cookie and if it is set then we place the data we want in the request’s context and call the next handler which was passed in as an argument…

```go
func AddContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Println(r.Method, "-", r.RequestURI)
		cookie, _ := r.Cookie("username")
		if cookie != nil {
			//Add data to context
			ctx := context.WithValue(r.Context(), "Username", cookie.Value)
			next.ServeHTTP(w, r.WithContext(ctx))
		} else {
			next.ServeHTTP(w, r)
		}
	})
}
```

As well we need to use that new middleware in the router and we do that in 1 or 2 ways…

First we can add the context only to specific routes, like so:

- mux.HandleFunc(“/”, StatusPage)

becomes:

- mux.Handle(“/”, AddContext(http.HandlerFunc(StatusPage)))

Or second, we can add it to the router itself:

- log.Println(“Start server on port :8085”)
- log.Fatal(http.ListenAndServe(”:8085”, mux))

becomes

- log.Println(“Start server on port :8085”)
- contextedMux := AddContext(mux)
- log.Fatal(http.ListenAndServe(”:8085”, contextedMux))
  Once you have done all this we can now modify the ‘StatusPage’ handler to look for and react to the data that is now in the context.

```go
func StatusPage(w http.ResponseWriter, r *http.Request) {
	//Get data from context
	if username := r.Context().Value("Username"); username != nil {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Hello " + username.(string) + "\n"))
	} else {
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte("Not Logged in"))
	}
}
```

It’s good to note that once we get the data out of the context we need to (cast) it to the proper type to use it. This is because the context Value() function returns an interface{} type. ( – See: ‘username.(string)’ )

I hope this quick intro to usign the Context object is useful, also I might write in the future about context With Cancel, Deadline and Timeout as they can also be useful in many scenarios.

Check out the entire code for this article below…

Happy GOing!!

```go

package main

import (
	"context"
	"log"
	"net/http"
	"time"
)

func AddContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Println(r.Method, "-", r.RequestURI)
		cookie, _ := r.Cookie("username")
		if cookie != nil {
			//Add data to context
			ctx := context.WithValue(r.Context(), "Username", cookie.Value)
			next.ServeHTTP(w, r.WithContext(ctx))
		} else {
			next.ServeHTTP(w, r)
		}
	})
}

func StatusPage(w http.ResponseWriter, r *http.Request) {
	//Get data from context
	if username := r.Context().Value("Username"); username != nil {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Hello " + username.(string) + "\n"))
	} else {
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte("Not Logged in"))
	}
}

func LoginPage(w http.ResponseWriter, r *http.Request) {
	expiration := time.Now().Add(365 * 24 * time.Hour)  ////Set to expire in 1 year
	cookie := http.Cookie{Name: "username", Value: "alice_cooper@gmail.com", Expires: expiration}
	http.SetCookie(w, &cookie)
}


func LogoutPage(w http.ResponseWriter, r *http.Request) {
	expiration := time.Now().AddDate(0, 0, -1)	//Set to expire in the past
	cookie := http.Cookie{Name: "username", Value: "alice_cooper@gmail.com", Expires: expiration}
	http.SetCookie(w, &cookie)
}


func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/", StatusPage)
	mux.HandleFunc("/login", LoginPage)
	mux.HandleFunc("/logout", LogoutPage)

	log.Println("Start server on port :8085")
	contextedMux := AddContext(mux)
	log.Fatal(http.ListenAndServe(":8085", contextedMux))
}
```
