FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production
COPY dist/ ./dist/
USER node
EXPOSE 8318
ENTRYPOINT ["node", "dist/index.js"]
