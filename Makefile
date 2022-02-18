-include .env

# Variables
PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = poetry-template
SOURCE_DIR := src
TEST_DIR := tests
# python
PYTHON := python
# Docker
IMAGE :=
VERSION := 0.1.0


.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

.PHONY: help
help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

.PHONY: clean
clean: clean-build clean-pyc clean-test docker-remove ## remove all build, test, coverage and Python artifacts

.PHONY: clean-build
clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

.PHONY: clean-pyc
clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

.PHONY: clean-test
clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

.PHONY: clean-docs
clean-docs: clean-apidocs ## generate Sphinx HTML documentation, including API docs
	rm -f docs/poetry-template.rst
	rm -f docs/modules.rst
	$(MAKE) -C docs clean

.PHONY: clean-apidocs
clean-apidocs:
	rm -f docs/poetry-template.*.rst
	rm -f docs/poetry-template.rst
	rm -f docs/modules.rst

.PHONY: lint
# lint: test check-codestyle check-safety ## check style with flake8
lint: test check-codestyle ## check style with flake8

.PHONY: codestyle
codestyle: ## run formatting
	poetry run isort --settings-path pyproject.toml ./
	poetry run black --config pyproject.toml ./

.PHONY: formatting
formatting: codestyle ## run formatting

.PHONY: check-codestyle
check-codestyle: ## check codestyle without formatting
	poetry run isort --diff --check-only --settings-path pyproject.toml ./
	poetry run black --diff --check --config pyproject.toml ./
	poetry run flake8 --config setup.cfg ./

.PHONY: test
test: ## run tests
	poetry run pytest -v $(TEST_DIR) -n auto --cov=$(SOURCE_DIR) --cov-report="html:htmlcov"
	-$(BROWSER) htmlcov/index.html

.PHONY: test-all
test-all: ## run tests on every Python version with tox
	poetry run tox

.PHONY: mypy
mypy: ## run mypy type check
	poetry run mypy --config-file pyproject.toml $(SOURCE_DIR)

.PHONY: check-safety
check-safety: ## check code safety with poetry
	poetry check
	poetry run safety check --full-report

.PHONY: docs
docs: clean-docs apidocs ## generate Sphinx HTML documentation, including API docs
	$(MAKE) -C docs html
	-$(BROWSER) docs/_build/html/index.html

.PHONY: apidocs
apidocs: clean-apidocs ## generate Sphinx API docs
	poetry run sphinx-apidoc -f -o docs/ $(SOURCE_DIR) $(SOURCE_DIR_EXCLUDES)

.PHONY: server-apidocs
server-apidocs: clean-apidocs ## compile the api docs watching for changes
	watchmedo shell-command -p '*.py' -c 'rm -f docs/poetry-template.*.rst && poetry run sphinx-apidoc -f -o docs/ $(SOURCE_DIR) $(SOURCE_DIR_EXCLUDES)' -R $(SOURCE_DIR)

.PHONY: server-docs
server-docs: clean-docs apidocs ## compile the docs watching for changes
	$(MAKE) -C docs livehtml

.PHONY: lock
lock:
	poetry lock -n && poetry export --without-hashes > requirements.txt

requirements.txt: poetry.lock
	poetry export --without-hashes > requirements.txt

.PHONY: release
release: dist ## package and upload a release
	poetry publish --repository imlab-gitlab -u $(CI_JOB_USER) -p $(CI_JOB_TOKEN)

.PHONY: dist
dist: clean-build ## builds source and wheel package
	poetry build
	ls -l dist

.PHONY: install
install: clean ## install the package to the active Python's site-packages
	poetry install -n
	-poetry run pre-commit install

.PHONY: uninstall
uninstall: clean ## uninstall the package to the active Python's site-packages
	poetry env remove python

.PHONY: version-up-major version-up-minor version-up-patch
version-up-major: ## update semantic version number
	poetry run bump2version major
version-up-minor: ## update semantic version number
	poetry run bump2version minor
version-up-patch: ## update semantic version number
	poetry run bump2version patch

.PHONY: poetry-download poetry-remove
poetry-download: ## download poetry
	curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | $(PYTHON) -
poetry-remove: ## remove poetry
	curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | $(PYTHON) - --uninstall

pre-commit-install: ## install pre-commit
	poetry run pre-commit install

.PHONY: docker-build docker-build-with-cache docker-remove
# Example: make docker-build VERSION=latest
# Example: make docker-build IMAGE=some_name VERSION=0.1.0
docker-build: ## build docker image
	@echo Building docker $(IMAGE):$(VERSION) ...
	docker build \
		-t $(IMAGE):latest \
		-t $(IMAGE):$(VERSION) \
		-f ./docker/Dockerfile --no-cache \
		.

docker-build-with-cache: ## build docker image without using cache
	@echo Building docker $(IMAGE):$(VERSION) ...
	docker build \
		-t $(IMAGE):latest \
		-t $(IMAGE):$(VERSION) \
		-f ./docker/Dockerfile \
		.

docker-login:
	@docker login "" -u $(CI_JOB_USER) -p $(CI_JOB_TOKEN)

docker-push: docker-login ## push docker image
	@echo Push docker $(IMAGE):$(VERSION) ...
	docker push $(IMAGE):latest
	docker push $(IMAGE):$(VERSION)

# Example: make docker-remove VERSION=latest
# Example: make docker-remove IMAGE=some_name VERSION=0.1.0
docker-remove: ## remove docker image
	@echo Removing docker $(IMAGE):$(VERSION) ...
	-docker rmi -f $(IMAGE):$(VERSION)
