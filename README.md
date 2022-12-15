# spi-doc-uploader

To test locally, start the local server

```
env LOCAL_LAMBDA_SERVER_ENABLED=true swift run
```

and trigger the endpoint:

```
curl -X POST -d 'foo' http://127.0.0.1:7000/invoke
```
