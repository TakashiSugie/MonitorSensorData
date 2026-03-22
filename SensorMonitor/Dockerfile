FROM node:20-slim

WORKDIR /app

# 非rootユーザーを作成
RUN groupadd -r appuser && useradd -r -g appuser appuser

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY . .

# 非rootユーザーに切り替え
USER appuser

# Cloud Run は PORT 環境変数でポートを指定
ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "const http=require('http');const r=http.get('http://localhost:'+(process.env.PORT||8080)+'/api/status',res=>{process.exit(res.statusCode===200?0:1)});r.on('error',()=>process.exit(1))"

CMD ["node", "server.js"]
