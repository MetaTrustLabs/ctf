from flask import Flask, request
import os
import requests
app = Flask(__name__)

@app.route('/sendsend')
def sadfh9obdfe1():
    send = request.headers.get('abc')
    requests.get('http://127.0.0.1:8081/hack?run='+send[1:])


if "__main__" == __name__:
    app.run(host="0.0.0.0",port = 5002)