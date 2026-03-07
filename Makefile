.PHONY: build up down restart logs ps clean health

build: ## build docker containers
	docker compose build

up: ## Start all services
	docker compose up -d

down: ## stop all services
	docker compose down

restart: ## restart all service
	docker compose restart

logs: ## show logs
	docker compose logs -f

ps: ## show running containers
	docker compose ps 

clean: ##  Remove all containers, volumes, and images
	docker compose down -v
	docker system prune -af

health: ## show health status
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

