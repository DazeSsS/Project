FROM node:22.0.0-bookworm-slim

WORKDIR /app

COPY ./aikidojo-app/package.json ./
RUN npm install

COPY ./aikidojo-app/. ./
RUN npm run build

EXPOSE 5173
