# spi-doc-uploader

To test locally, start the local server

```
env LOCAL_LAMBDA_SERVER_ENABLED=true swift run
```

and trigger the endpoint:

```
curl -X POST -d 'foo' http://127.0.0.1:7000/invoke
```

## Update `package.json` dependencies

```
npx npm-check-updates -u
npm install
```

Source: https://stackoverflow.com/a/22849716/1444152

## Links

- https://fabianfett.dev/getting-started-with-swift-aws-lambda-runtime
- https://www.createwithswift.com/tutorial-getting-started-with-swift-aws-lambda-runtime/

