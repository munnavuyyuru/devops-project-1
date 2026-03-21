.PHONY: build up down restart logs ps clean health scan backup restore list-backups logs-all logs-backend logs-errors logs-follow grafana

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


scan: ## Run security scan on all images
	@./scripts/Trivy-scan.sh

prod-check: build scan ## Build and scan before deploying
	@echo "Production checks passed!"

backup: ## Create database backup
	@./scripts/backup/backup-database.sh

restore: ## Restore database from backup (requires BACKUP=path/to/backup.sql.gz)
	@if [ -z "$(BACKUP)" ]; then \
		./scripts/backup/restore-database.sh; \
	else \
		./scripts/backup/restore-database.sh $(BACKUP); \
	fi

list-backups: ## List all backups
	@echo "Daily backups:"
	@ls -lh backups/daily/*.gz 2>/dev/null || echo "  No daily backups"
	@echo ""
	@echo "Weekly backups:"
	@ls -lh backups/weekly/*.gz 2>/dev/null || echo "  No weekly backups"
	@echo ""
	@echo "Monthly backups:"
	@ls -lh backups/monthly/*.gz 2>/dev/null || echo "  No monthly backups"

logs-all: ## View all container logs via Loki
	@./scripts/logs.sh -n 100

logs-backend: ## View backend logs
	@./scripts/logs.sh -c backend -n 50

logs-errors: ## View all error logs
	@./scripts/logs.sh -l error -n 50

logs-follow: ## Follow all logs in real-time
	@./scripts/logs.sh -f

grafana: ## Open Grafana dashboard
	@echo "Opening Grafana..."
	@echo "URL: http://localhost:3001"
	@echo "Username: admin"
	@echo "Password: admin"
