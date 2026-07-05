# OpenShad production image — the Next.js app at apps/v4, built from source.
#
# OpenShad is a customized fork of shadcn-ui/ui, so the image builds locally
# instead of pulling an upstream image (inverse of the umami/shlink/karakeep
# pattern, same reasoning: build only what is actually customized).
#
# The bun-based `registry:build` step is intentionally NOT run here: the
# generated registry indices (registry/__index__.tsx, registry/bases/__index__.tsx)
# and the public/r/** JSON exports are committed to the repo. Regenerate them
# locally (pnpm registry:build) when authored registry sources change, then
# rebuild this image.

FROM node:22-alpine AS base
# node:20 is EOL (April 2026); 22 is the active LTS. Pinned pnpm matches the
# repo's packageManager field.
RUN npm install -g pnpm@10.33.4
WORKDIR /app

FROM base AS build
# Fetch packages from the lockfile alone first so the download layer caches
# independently of source changes; the offline install after COPY runs
# apps/v4's fumadocs-mdx postinstall, which needs sources present.
COPY pnpm-lock.yaml pnpm-workspace.yaml ./
RUN CI=true pnpm fetch
COPY . .
RUN CI=true pnpm install --frozen-lockfile --offline
# The shadcn workspace package dist backs the app's shadcn/preset|schema|utils imports.
RUN pnpm --filter=@shadcn/react build && pnpm --filter=shadcn build
# NEXT_PUBLIC_* values are inlined into client bundles at build time.
ARG NEXT_PUBLIC_APP_URL=http://localhost:4000
ARG NEXT_PUBLIC_V0_URL=https://v0.dev
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    NEXT_PUBLIC_V0_URL=$NEXT_PUBLIC_V0_URL \
    BUILD_STANDALONE=1 \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_OPTIONS=--max-old-space-size=6144
RUN cd apps/v4 && pnpm exec next build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    PORT=4000 \
    HOSTNAME=0.0.0.0 \
    NEXT_TELEMETRY_DISABLED=1
# Server code reads NEXT_PUBLIC_APP_URL from the environment at runtime
# (apps/v4/app/layout.tsx), so it must exist here too, not just at build time.
ARG NEXT_PUBLIC_APP_URL=http://localhost:4000
ARG NEXT_PUBLIC_V0_URL=https://v0.dev
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    NEXT_PUBLIC_V0_URL=$NEXT_PUBLIC_V0_URL
COPY --from=build --chown=node:node /app/apps/v4/.next/standalone ./
COPY --from=build --chown=node:node /app/apps/v4/.next/static ./apps/v4/.next/static
COPY --from=build --chown=node:node /app/apps/v4/public ./apps/v4/public
USER node
EXPOSE 4000
# /init requires a full design-system config — bare /init is a 400 by design.
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=30s \
  CMD wget --spider -q "http://127.0.0.1:4000/init?base=base&style=nova&iconLibrary=lucide&baseColor=neutral&theme=neutral&font=inter&menuAccent=subtle&menuColor=default&radius=default" || exit 1
CMD ["node", "apps/v4/server.js"]
