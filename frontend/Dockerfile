## Stage 1

FROM node:20-alpine AS builder 
WORKDIR /app 

COPY package*.json ./  

RUN npm ci 

ARG VITE_AUTH_URL
ARG VITE_POKEMON_URL
ARG VITE_FAVORITES_URL

ENV VITE_AUTH_URL=$VITE_AUTH_URL
ENV VITE_POKEMON_URL=$VITE_POKEMON_URL
ENV VITE_FAVORITES_URL=$VITE_FAVORITES_URL

COPY . .

RUN npm run build 

## Stage 2

FROM nginx:alpine 

COPY --from=builder /app/dist /usr/share/nginx/html 

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]