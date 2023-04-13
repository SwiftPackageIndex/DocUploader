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

## Release testing

There is currently no automated test setup to validate a new release, because it would be quite complex to set up.

Instead, use the `dev` environment to validate a new release as follows:

- Run the tests

```
docker run --rm -v "$PWD":/host -w /host swift:5.8.0-amazonlinux2 swift test
```

- Deploy the new version to the "test" lambda

```
make deploy-test
```

- Trigger a doc upload via the "test" lambda by downloading a `dev-` doc bundle from `spi-docs-inbox` and uploading it to `spi-scratch-inbox`:

```bash
❯ aws s3 cp s3://spi-docs-inbox/dev-swiftpackageindex-semanticversion-0.3.4-4e7b8a37.zip .
❯ aws s3 cp dev-swiftpackageindex-semanticversion-0.3.4-4e7b8a37.zip s3://spi-scratch-inbox/
```

- Verify docs updated in `spi-dev-docs` for the given package (either by checking the timestamp or by deleting the version first and ensuring it re-appears)

## Pushing a new release

Once a new release has been validated, push a new release as follows:

- Tag the version
- Run `make deploy-prod`
