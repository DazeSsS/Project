rebuild: build down up

build:
	docker compose build

build_nocache:
	docker compose build --no-cache

up:
	docker compose up -d

down:
	docker compose down

start:
	docker compose start

stop:
	docker compose stop

restart:
	docker compose restart

rebuild-prod: build-prod down-prod up-prod

build-prod:
	docker compose -f docker-compose.prod.yaml build

up-prod:
	docker compose -f docker-compose.prod.yaml up -d

down-prod:
	docker compose -f docker-compose.prod.yaml down

start-prod:
	docker compose -f docker-compose.prod.yaml start

stop-prod:
	docker compose -f docker-compose.prod.yaml stop

restart-prod:
	docker compose -f docker-compose.prod.yaml restart

prune:
	docker system prune

makemigrations:
	docker compose run --build --rm api python3 src/manage.py makemigrations

createsuperuser:
	docker compose run --rm api python3 src/manage.py createsuperuser

populate:
	docker compose run --rm api python3 src/manage.py populate_db

flush:
	docker compose run --rm api python3 src/manage.py flush
