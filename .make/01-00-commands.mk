##@ [Utility Commands]

.PHONY: socket-sh
socket-sh: ## Execute shell script in Socket container with arguments ARGS="pwd"
	@$(EXECUTE_IN_DOCKER_SOCKET_CONTAINER) $(ARGS);

.PHONY: traefik-sh
traefik-sh: ## Execute shell script in Traefik container with arguments ARGS="pwd"
	@$(EXECUTE_IN_TRAEFIK_CONTAINER) $(ARGS);

.PHONY: logrotate-sh
logrotate-sh: ## Execute shell script in Logrotate container with arguments ARGS="pwd"
	@$(EXECUTE_IN_LOGROTATE_CONTAINER) $(ARGS);
