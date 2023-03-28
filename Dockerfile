# Base image for node
FROM node:19 as node_base

WORKDIR /usr/src/app
# Install pip and requirements

# Base image for runtime
FROM ubuntu:22.04 as base

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam

WORKDIR /usr/src/app

COPY --chmod=0755 compile.sh .

# Install MongoDB and necessary tools
RUN apt update && \
    apt install -y curl wget gnupg python3-pip git && \
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    git clone https://github.com/ggerganov/llama.cpp.git --branch master-d5850c5


# copy & install python reqs
COPY ./api/requirements.txt api/requirements.txt
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r ./api/requirements.txt

# Dev environment
FROM base as dev
ENV NODE_ENV='development'

# Install Node.js and npm packages
COPY --from=node_base /usr/local /usr/local
COPY ./web/package*.json ./
RUN npm ci

# Copy the rest of the project files
COPY web /usr/src/app/web
COPY ./api /usr/src/app/api

COPY --chmod=0755 dev.sh /usr/src/app/dev.sh
CMD ./dev.sh

# Build frontend
FROM node_base as frontend_builder

COPY ./web/package*.json ./
RUN npm ci

COPY ./web /usr/src/app/web/
WORKDIR /usr/src/app/web/
RUN npm run build

# Runtime environment
FROM base as release

ENV NODE_ENV='production'
WORKDIR /usr/src/app

COPY --from=frontend_builder /usr/src/app/web/build /usr/src/app/api/static/
COPY ./api /usr/src/app/api

COPY --chmod=0755 deploy.sh /usr/src/app/deploy.sh

CMD ./deploy.sh