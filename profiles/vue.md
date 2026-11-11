# Vue profile (read once per session when working on frontend/)

- Vue 3 + TypeScript strict + Vite. `<script setup lang="ts">`, Composition API only; no Options API, no `any`.
- Structure: `src/api` (typed client from the OpenAPI schema), `src/stores` (Pinia, one per domain), `src/composables`, `src/components` (presentational) vs `src/views` (route-level, container). Logic lives in composables/stores, not in templates.
- Types: generate `src/api/schema.d.ts` with `npm run gen:api`; never hand-write API types or edit the generated file.
- Components: typed `defineProps`/`defineEmits`, small and single-purpose, `v-for` always keyed, no `v-html` with dynamic content, prefer `computed` over watchers.
- State & data: Pinia for shared state; every request has loading, error and empty states; no tokens or personal data in `localStorage`.
- Accessibility: semantic elements, labels on every input, visible focus, keyboard reachable, sufficient contrast.
- Tests: Vitest for composables/stores and components with user-visible logic; Playwright only for critical flows.
- Gate before commit: `npm run typecheck`, `npm run lint`, `npm test`.
- UI quality (front projects): follow the `taste-skill` / `web-design-guidelines` skills; avoid generic AI-looking layouts.
- Dependencies: every new package needs the developer's approval (guard hook asks).
