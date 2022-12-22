
# Example settings
build:
	scripts/build.sh doc-uploader
	scripts/package.sh doc-uploader
    
deploy:
	sam deploy

deploy-arm64:
	sam deploy --parameter-overrides Arch=arm64
