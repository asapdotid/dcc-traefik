# Enable buildkit for docker and docker-compose by default for every environment.
# For specific environments (e.g. MacBook with Apple Silicon M1 CPU) it should be turned off to work stable
# - this can be done in the .make/.env file
DOCKER_BUILDKIT ?= 1
COMPOSE_DOCKER_CLI_BUILD ?= 1

# Container names
## must match the names used in the composer.yml files
DOCKER_SERVICE_NAME_DOCKER_SOCKET := dockersocket
DOCKER_SERVICE_NAME_TRAEFIK := traefik
DOCKER_SERVICE_NAME_LOGROTATE :=logrotate

DOCKER_SERVICE_NAME?=
EXECUTE_IN_ANY_CONTAINER?=
EXECUTE_IN_DOCKER_SOCKET_CONTAINER?=
EXECUTE_IN_TRAEFIK_CONTAINER?=
EXECUTE_IN_LOGROTATE_CONTAINER?=

# Set docker compose file
DOCKER_COMPOSE_FILE := $(PROJECT_SOURCE_DIR)/compose.yml

# we need a couple of environment variables for docker-compose so we define a make-variable that we can
# then reference later in the Makefile without having to repeat all the environment variables
DOCKER_COMPOSE_COMMAND:= \
		CURDIR=$(CURDIR) \
		DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) \
		COMPOSE_DOCKER_CLI_BUILD=$(COMPOSE_DOCKER_CLI_BUILD) \
    docker compose -p $(DOCKER_PROJECT)

DOCKER_COMPOSE:=$(DOCKER_COMPOSE_COMMAND) -f $(DOCKER_COMPOSE_FILE)

# we can pass EXECUTE_IN_CONTAINER=true to a make invocation in order to execute the target in a docker container.
# Caution: this only works if the command in the target is prefixed with a $(EXECUTE_IN_*_CONTAINER) variable.
# If EXECUTE_IN_CONTAINER is NOT defined, we will check if make is ALREADY executed in a docker container.
# We still need a way to FORCE the execution in a container, e.g. for Gitlab CI, because the Gitlab
# Runner is executed as a docker container BUT we want to execute commands in OUR OWN docker containers!
EXECUTE_IN_CONTAINER?=
ifndef EXECUTE_IN_CONTAINER
	# check if 'make' is executed in a docker container, see https://stackoverflow.com/a/25518538/413531
	# `wildcard $file` checks if $file exists, see https://www.gnu.org/software/make/manual/html_node/Wildcard-Function.html
	# i.e. if the result is "empty" then $file does NOT exist => we are NOT in a container
	ifeq ("$(wildcard /.dockerenv)","")
		EXECUTE_IN_CONTAINER=true
	endif
endif
ifeq ($(EXECUTE_IN_CONTAINER),true)
	EXECUTE_IN_ANY_CONTAINER := $(DOCKER_COMPOSE) exec -T $(DOCKER_SERVICE_NAME)
	EXECUTE_IN_DOCKER_SOCKET_CONTAINER := $(DOCKER_COMPOSE) exec -T $(DOCKER_SERVICE_NAME_DOCKER_SOCKET)
  EXECUTE_IN_TRAEFIK_CONTAINER := $(DOCKER_COMPOSE) exec -T $(DOCKER_SERVICE_NAME_TRAEFIK)
	EXECUTE_IN_LOGROTATE_CONTAINER := $(DOCKER_COMPOSE) exec -T $(DOCKER_SERVICE_NAME_LOGROTATE)
endif

# Traefik copy config template
copy-config-template:
	@if [ -d $(TRAEFIK_CONFIG_DIR) ]; then rm -rf $(TRAEFIK_CONFIG_DIR); fi
	@cp -r $(TRAEFIK_CONFIG_TEMPLATE_DIR) $(TRAEFIK_CONFIG_DIR)

# Traefik copy secrets template
copy-secrets-template:
	@if [ -d $(TRAEFIK_SECRETS_DIR) ]; then rm -rf $(TRAEFIK_SECRETS_DIR); fi
	@cp -r $(TRAEFIK_SECRETS_TEMPLATE_DIR) $(TRAEFIK_SECRETS_DIR)

# Traefik settings config
setup-config: copy-config-template
	@$(YQ) 'with(.api.dashboard; . = $(TRAEFIK_DASHBOARD)) | with(.entryPoints.websecure.http.tls; .domains = [{"main": "'$(TRAEFIK_DOMAIN_NAME)'", "sans": ["*.'$(TRAEFIK_DOMAIN_NAME)'"]}]) | with(.log; .level = "'$(TRAEFIK_LOG_LEVEL)'")' -i $(TRAEFIK_CONFIG_FILE)
	@$(YQ) 'with(.http.middlewares.midSecurityHeaders.headers.customResponseHeaders; .X-Robots-Tag = "'$(TRAEFIK_SEC_ROBOTS_TAG)'") | with(.http.middlewares.midSecurityHeaders.headers; .referrerPolicy = "'$(TRAEFIK_SEC_REFERRER_POLICY)'") | with(.http.middlewares.midSecurityHeaders.headers; .contentSecurityPolicy = "'$(TRAEFIK_SEC_CSP)'") | with(.http.middlewares.midSecurityHeaders.headers; .permissionsPolicy = "'$(TRAEFIK_SEC_PERMISSION_POLICY)'") | with(.http.middlewares.midCorsHeaders.headers; .accessControlAllowHeaders = ["'$(TRAEFIK_CORS_ALLOW_HEADERS)'"])' -i $(TRAEFIK_MIDDLEWARES_CONFIG_FILE)
	@$(YQ) 'with(.http.routers.dashboard; .rule = "Host(`'$(TRAEFIK_DASHBOARD_SUBDOMAIN).$(TRAEFIK_DOMAIN_NAME)'`)")' -i $(TRAEFIK_ROUTES_CONFIG_FILE)

# Check if secrets exist
check-secrets:
	@if [ -f $(TRAEFIK_SECRETS_DIR)/cloudflare_email.secret ] && [ -f $(TRAEFIK_SECRETS_DIR)/cloudflare_api_token.secret ] && [ -f $(TRAEFIK_SECRETS_DIR)/traefik_users.secret ]; then \
	 	if grep -qE "cloudflare_email_account@domain.com" "$(TRAEFIK_SECRETS_DIR)/cloudflare_email.secret"; then \
			echo "Secrets exist but not valid, please change email address on src/cloudflare_email.secret"; \
		fi; \
		if grep -qE "cloudflare_token_please_change_with_real_api_token" "$(TRAEFIK_SECRETS_DIR)/cloudflare_api_token.secret"; then \
			echo "Secrets exist but not valid, please change API token on src/cloudflare_api_token.secret"; \
		fi;\
	else \
		echo "Secrets do not exist"; \
		exit 1; \
	fi

# Validate environment variables
validate-variables:
	@$(if $(DOCKER_PROJECT),,$(error DOCKER_PROJECT named is undefined - Did you run make init?))

##@ [Secrets]

.PHONY: secret
secret: copy-secrets-template ## Copy secrets template

##@ [Docker Compose]

.PHONY: up
up: setup-config check-secrets validate-variables ## Start all containers. Optional variable DOCKER_SERVICE_NAME.
	@$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE_NAME)

.PHONY: down
down: validate-variables ## Stop and remove all docker containers.
	@$(DOCKER_COMPOSE) down --remove-orphans -v

.PHONY: restart
restart: validate-variables ## Restart all docker containers.
	@$(DOCKER_COMPOSE) restart $(DOCKER_SERVICE_NAME)

.PHONY: config
config: validate-variables ## Docker config of containers.
	@$(DOCKER_COMPOSE) config $(DOCKER_SERVICE_NAME)

.PHONY: logs
logs: validate-variables ## Docker logs of containers.
	@$(DOCKER_COMPOSE) logs --tail=100 -f $(DOCKER_SERVICE_NAME)

.PHONY: ps
ps: validate-variables ## Docker composer PS containers.
	@$(DOCKER_COMPOSE) ps $(DOCKER_SERVICE_NAME)

##@ [Docker Utils]

.PHONY: clean
clean: ## Removing dangling and unused images
	@docker rmi -f $$(docker images -f "dangling=true" -q)

.PHONY: prune
prune: ## Remove ALL unused docker resources, including volumes
	@docker system prune -a -f --volumes
