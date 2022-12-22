
# Example settings
build:
	scripts/build.sh doc-uploader
	scripts/package.sh doc-uploader
    
deploy:
	sam deploy \
		--no-confirm-changeset \
		--no-fail-on-empty-changeset \
		--region us-east-2 \
		--s3-bucket spi-deployment-artifacts \
		--s3-prefix doc-uploader \
		--stack-name DocUploaderLambda \
		--capabilities CAPABILITY_IAM
