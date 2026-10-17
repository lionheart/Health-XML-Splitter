# Copyright 2015-2018 Lionheart Software LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GO ?= go
GOFMT ?= gofmt

.DEFAULT_GOAL := build
.PHONY: build test vet format format-go go-library test-go test-swift-bridge

build: go-library

go-library:
	GO_BINARY="$(GO)" bash scripts/build-go-library.sh

test: test-go test-swift-bridge

test-go:
	$(GO) test -race ./...

vet:
	$(GO) vet ./...

test-swift-bridge:
	GO_BINARY="$(GO)" bash scripts/test-swift-bridge.sh

format: format-go
	swift format --in-place "XML Splitter/Parser.swift" "XML Splitter/main.swift" tests/BridgeSmoke.swift

format-go:
	$(GOFMT) -w internal/splitter bindings/healthsplitter
