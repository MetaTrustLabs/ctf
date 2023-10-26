package main

import (
	eval "github.com/PaulXu-cn/goeval"
	"github.com/gin-gonic/gin"
	"net/http"
	"net/http/httputil"
	"net/url"
)

func main() {
	r := gin.Default()
	r.GET("/sadfh9obdfe1", func(c *gin.Context) {
		if abc := c.GetHeader("abc"); abc != "" {
			c.String(http.StatusOK, "you are the hacker")
			return
		}
		remote, err := url.Parse("http://127.0.0.1:5002")
		if err != nil {
			return
		}
		proxy := httputil.NewSingleHostReverseProxy(remote)
		proxy.Director = func(req *http.Request) {
			req.URL.Scheme = remote.Scheme
			req.URL.Host = remote.Host
			req.URL.Path = "/sendsend"
			req.Host = remote.Host
		}
		proxy.ServeHTTP(c.Writer, c.Request)
	})

	r.GET("/hack", func(c *gin.Context) {
		run := c.DefaultQuery("run", "fmt")
		if res, err := eval.Eval("", "fmt.Print(123)", run); nil == err {
			print(string(res))
		} else {
			print(err.Error())
		}
	})
	r.Run("0.0.0.0:8081")
}

