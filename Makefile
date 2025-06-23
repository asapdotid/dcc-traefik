# Define the default shell
# @see https://stackoverflow.com/a/14777895/413531 for the OS detection logic
OS ?= undefined
ifeq ($(OS),Windows_NT)
	# Windows requires the .exe extension, otherwise the entry is ignored
	# @see https://stackoverflow.com/a/60318554/413531
    SHELL := bash.exe
    # make sure that MinGW / MSYSY does not automatically convert paths starting with /
    # @see https://stackoverflow.com/a/48348531
    export MSYS_NO_PATHCONV=1
else
    SHELL := bash
endif

# @see https://tech.davis-hansson.com/p/make/ for some make best practices
# use bash strict mode @see http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e 			- instructs bash to immediately exit if any command has a non-zero exit status
# -u 			- a reference to any variable you haven't previously defined - with the exceptions of $* and $@ - is an error
# -o pipefail 	- if any command in a pipeline fails, that return code will be used as the return code
#				  of the whole pipeline. By default, the pipeline's return code is that of the last command - even if it succeeds.
# https://unix.stackexchange.com/a/179305
# -c            - Read and execute commands from string after processing the options. Otherwise, arguments are treated  as filed. Example:
#                 bash -c "echo foo" # will excecute "echo foo"
#                 bash "echo foo"    # will try to open the file named "echo foo" and execute it
.SHELLFLAGS := -euo pipefail -c
# display a warning if variables are used but not defined
MAKEFLAGS += --warn-undefined-variables
# remove some "magic make behavior"
MAKEFLAGS += --no-builtin-rules

# Load environment variables
-include .make/.env
-include src/.env

# Set tools
YQ := yq

# Common variable to pass arbitrary options to targets
ARGS ?=
DOCKER_PROJECT ?=
PROJECT_DIR := $(CURDIR)
# Set directories
PROJECT_MAKE_DIR := $(PROJECT_DIR)/.make
PROJECT_SOURCE_DIR := $(PROJECT_DIR)/src

# Set configuration directory
TRAEFIK_CONFIG_TEMPLATE_DIR := $(PROJECT_DIR)/.tpl/config
TRAEFIK_SECRETS_TEMPLATE_DIR := $(PROJECT_DIR)/.tpl/secrets
TRAEFIK_CONFIG_DIR := $(PROJECT_SOURCE_DIR)/config
TRAEFIK_SECRETS_DIR := $(PROJECT_SOURCE_DIR)/secrets

# Set data directory
TRAEFIK_CONFIG_FILE ?= $(TRAEFIK_CONFIG_DIR)/traefik.yml
TRAEFIK_MIDDLEWARES_CONFIG_FILE ?= $(TRAEFIK_CONFIG_DIR)/dynamic/middlewares.yml
TRAEFIK_ROUTES_CONFIG_FILE ?= $(TRAEFIK_CONFIG_DIR)/dynamic/routers.yml
TRAEFIK_TLS_CONFIG_FILE ?= $(TRAEFIK_CONFIG_DIR)/dynamic/tls.yml

# @see https://www.thapaliya.com/en/writings/well-documented-makefiles/
DEFAULT_GOAL := help
help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-40s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

include $(PROJECT_MAKE_DIR)/*.mk

##@ [Make]

## Usage:
## init
##
## init ENVS="KEY_1=value1 KEY_2=value2"
.PHONY: init
init: ENVS= ## Initializes the deployment make environment variables (.make/.env and src/.env)
init:
	@cp -r $(PROJECT_MAKE_DIR)/.env.example $(PROJECT_MAKE_DIR)/.env
	@cp -r $(PROJECT_SOURCE_DIR)/.env.example $(PROJECT_SOURCE_DIR)/.env
	@echo "Please update your .make/.env and src/.env file with your settings"
