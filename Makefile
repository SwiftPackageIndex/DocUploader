VERSION := $(shell git describe --always --tags --dirty)
VERSION_FILE = Sources/DocUploader/Version.swift

version:
	@# avoid tracking changes for file:
	@git update-index --assume-unchanged $(VERSION_FILE)
	@echo VERSION: $(VERSION)
	@echo "public let LambdaVersion = \"$(VERSION)\"" > $(VERSION_FILE)

build: version
	scripts/build.sh doc-uploader
	scripts/package.sh doc-uploader
    
deploy-prod: build
	sam deploy \
		--stack-name DocUploaderLambda-Prod \
		--parameter-overrides Env=prod

deploy-test: build
	sam deploy \
		--stack-name DocUploaderLambda-Test \
		--parameter-overrides Env=test
