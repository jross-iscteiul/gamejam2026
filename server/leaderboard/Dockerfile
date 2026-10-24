FROM node:24-bookworm-slim
ENV NODE_ENV=production PORT=8080 DATABASE_PATH=/data/leaderboard.sqlite
WORKDIR /app
COPY --chown=node:node package.json server.mjs ./
RUN mkdir /data && chown node:node /data
USER node
EXPOSE 8080
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD node -e "fetch('http://127.0.0.1:8080/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "server.mjs"]
