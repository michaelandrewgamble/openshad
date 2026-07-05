# OpenShad — Progress

OpenShad is a fork of [shadcn-ui/ui](https://github.com/shadcn-ui/ui) (MIT) focused on the
`/create` project configurator and its `/init` backend, to be extended with our own
design-system opinions in Phase 3. Upstream remote is retained for pulling fixes.

## Phase 1 — Fork and run ✅ (2026-07-04)

- [x] Graft upstream history: `upstream` remote → blobless fetch → `main` reset to `upstream/main` (`d0fae528`)
- [x] `pnpm install` (pnpm auto-switched to pinned 10.33.4; ~2min)
- [x] Build workspace packages required by tests and app imports:
      `pnpm --filter=@shadcn/react build && pnpm --filter=shadcn build`
- [x] Baseline tests green **before any changes**: `pnpm exec vitest run apps/v4/app` — 6 files / 19 tests pass
      (2× /init: `route.test.ts`, `parse-config.test.ts`; 4× /create lib: `search-params`, `parse-preset-input`, `v0`, `preset-query`)
- [x] Dev server: `cd apps/v4 && pnpm dev` → http://localhost:4000 (Next 16.2.7 + Turbopack)
- [x] `/init` API verified: default + parameterized configs, `?only=` sparse mode, 400 on invalid input,
      `/init/md` markdown instructions; default response validates against `registryItemSchema` (real zod parse)
- [x] `/create` verified in a real browser (puppeteer + system Chrome): page loads with no console errors,
      preview iframe renders (`/preview/base/preview-02`), Shuffle changes URL params, undo via history back
      restores them, preset URL round-trips in a fresh page

### Dev setup requirements (fresh clone)

1. `pnpm install` (pnpm ≥10; auto-switches to pinned version)
2. `pnpm --filter=@shadcn/react build && pnpm --filter=shadcn build` — the `shadcn` workspace package's
   dist must exist or vitest/app imports of `shadcn/preset|schema|utils` fail to resolve
3. `cp apps/v4/.env.example apps/v4/.env.local` — **required**; `app/layout.tsx` does
   `new URL(process.env.NEXT_PUBLIC_APP_URL!)` and every SSR request 500s without it
4. `cd apps/v4 && pnpm dev` → port 4000. No registry build needed: generated indices
   (`registry/__index__.tsx`, `registry/bases/__index__.tsx`) and all `public/r/**` JSON (~4.8k files)
   are committed. `bun` is only required to *regenerate* the registry (`pnpm registry:build`).

### Notes / findings

- pnpm 10 blocked postinstall scripts (esbuild, sharp, puppeteer, msw, unrs-resolver) — everything works
  without approving them; puppeteer needs a system Chrome or `npx puppeteer browsers install chrome`.
- First-visit welcome dialog overlays the configurator and swallows real-mouse clicks until dismissed
  (Escape works) — automation/UX friction note for Phase 3.
- `/init/v0` is the only runtime path that fetches `public/r/*` JSON over HTTP; everything else is
  in-process calls to `@/registry/config` or direct imports of the generated indices.

## Docker ✅ (2026-07-04)

- [x] Multi-stage `Dockerfile` (node:22-alpine, pinned pnpm, `pnpm fetch` → offline install,
      workspace package builds, `next build` standalone; non-root runtime, healthcheck)
- [x] `docker-compose.yml` (build-from-source, `name: openshad`, explicit healthcheck) +
      `docker-compose.override.yml` (loopback `127.0.0.1:4000`, log rotation) + `renovate.json`
- [x] `next.config.mjs`: `output: standalone` + 600s static-gen timeout, both gated behind
      `BUILD_STANDALONE=1` so upstream scripts behave identically outside Docker
- [x] Image `openshad-app:latest` (1.55GB) verified end-to-end in a container:
      healthcheck green, /init schema-validated, browser E2E (iframe/shuffle/undo/preset) pass

### Docker notes

- Full unstripped site takes ~50min to bake (thousands of /view + docs pages; some pages need
  >60s static generation). Expected to drop to minutes after Phase 2 strip.
- `/init` without params is a 400 **by design** — healthchecks must probe with a full config
  query string (see Dockerfile comment).
- Deployment: manual `docker compose up -d --build` (host-services redeploy loop only pulls
  registry images, never builds). Cloudflare Tunnel ingress `openshad.michaelgamble.ca →
  http://localhost:4000` to be added in the Zero Trust dashboard.
- `@vercel/analytics` 404s (`/_vercel/insights/script.js`) in any non-Vercel deployment —
  console noise only; removed in Phase 2 anyway.
- og:url metadata bakes `NEXT_PUBLIC_APP_URL` at build time — pass the real public URL as a
  build arg for production images.

## Phase 2 — Strip to OpenShad (not started; awaits explicit go)

- [ ] Reachability analysis from `/create`, `/init`, registry pipeline, shared app infra (parallel agents)
- [ ] Strip manifest (keep / delete / uncertain — uncertain resolved by reading source)
- [ ] Sequential small-commit removal passes; tests + `/create` + `/init` smoke after each
- [ ] Remove `@vercel/analytics` and Vercel-specific code
- [ ] Rebrand chrome to OpenShad; LICENSE retains original MIT notice + derivation note

## Phase 3 — Diverge (later)

Extended token model, own themes/presets, custom registry items, customizer UX improvements.
