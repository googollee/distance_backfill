SCHEME := DistanceBackfill
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/DistanceBackfill.xcarchive
EXPORT_PATH := $(BUILD_DIR)/export
EXPORT_OPTIONS := ExportOptions.plist
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest

-include appstoreconnect/config.mk

APP_STORE_CONNECT_KEY_ID ?= $(ASC_KEY_ID)
APP_STORE_CONNECT_ISSUER_ID ?= $(ASC_ISSUER_ID)
APP_STORE_CONNECT_KEY_PATH ?= appstoreconnect/AuthKey_$(ASC_KEY_ID).p8

IN_GIT_REPO := $(shell git rev-parse --is-inside-work-tree 2>/dev/null)

ifeq ($(IN_GIT_REPO),true)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null)
GIT_DIRTY := $(shell git status --porcelain 2>/dev/null)
GIT_TAG := $(shell git describe --tags --exact-match 2>/dev/null)
ifneq ($(strip $(GIT_DIRTY)),)
RELEASE_VERSION := $(GIT_HASH)+
else ifneq ($(strip $(GIT_TAG)),)
RELEASE_VERSION := $(patsubst v%,%,$(GIT_TAG))
else
RELEASE_VERSION := $(GIT_HASH)
endif
else
RELEASE_VERSION :=
endif

BUILD_NUMBER := $(shell date +%Y%m%d%H)

.PHONY: generate test build release clean

generate:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen 未安装，请先执行: brew install xcodegen"; exit 1; }
	xcodegen generate

test: generate
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(SIMULATOR)'

build: generate
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(SIMULATOR)'

release: generate
	@echo "Marketing Version: $(RELEASE_VERSION)"
	@echo "Build Number: $(BUILD_NUMBER)"
	xcodebuild archive \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-destination 'generic/platform=iOS' \
		-allowProvisioningUpdates \
		-authenticationKeyPath "$(APP_STORE_CONNECT_KEY_PATH)" \
		-authenticationKeyID "$(APP_STORE_CONNECT_KEY_ID)" \
		-authenticationKeyIssuerID "$(APP_STORE_CONNECT_ISSUER_ID)" \
		MARKETING_VERSION="$(RELEASE_VERSION)" \
		CURRENT_PROJECT_VERSION="$(BUILD_NUMBER)"
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-authenticationKeyPath "$(APP_STORE_CONNECT_KEY_PATH)" \
		-authenticationKeyID "$(APP_STORE_CONNECT_KEY_ID)" \
		-authenticationKeyIssuerID "$(APP_STORE_CONNECT_ISSUER_ID)"

clean:
	rm -rf $(BUILD_DIR) Generated DistanceBackfill.xcodeproj
