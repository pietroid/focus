# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:22-alpine AS production
# The commit the image was built from, reported by /health so a deploy can
# check that the new build is the one answering.
ARG FOCUS_VERSION=dev
ENV FOCUS_VERSION=$FOCUS_VERSION
ENV NODE_ENV=production
ENV PORT=3002
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist

EXPOSE 3002
CMD ["node", "dist/main.js"]
