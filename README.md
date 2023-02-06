# spi-doc-uploader

SwiftPackageIndex helper package to upload and process documentation bundles.

![Doc Uploader](https://user-images.githubusercontent.com/65520/210773047-9c1f7cba-252c-4da9-a0f5-2ab8d1ed123d.png)

## Dependencies for deployment

Install the following AWS tools to be able to deploy:

```
brew install awscli
brew tap aws/tap
brew install aws-sam-cli
```

Deployment also requires [Docker for Mac](https://docs.docker.com/desktop/install/mac-install/).

Run

```
aws login
```

to set up the default credentials for deploying into AWS.

Subsequently, run either `make deploy-test` or `make deploy-prod` to deploy into the respective environment:

```
make deploy-test
```

## Lambda operation notes

https://docs.aws.amazon.com/lambda/latest/operatorguide/computing-power.html
