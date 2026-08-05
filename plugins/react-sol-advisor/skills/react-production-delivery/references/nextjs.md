# Next.js reference

Load this reference when the task involves App Router, server components, route
handlers, server actions, caching, revalidation, streaming, metadata, or bundle
boundaries.

- Correct server/client boundary and minimal client surface.
- Serializable server-to-client props.
- Server-side auth for actions and route handlers.
- Explicit cache and revalidation semantics based on the actual installed Next.js
  version.
- Parallel data fetching and avoided waterfalls.
- Suspense/streaming boundaries based on user-visible behavior.
- Avoided client duplication of server-owned data.
- Bundle-sensitive imports and conditional loading.
- Hydration correctness without suppressing unexpected mismatches.

Do not apply generic "latest Next.js" advice without checking the repository version
and current official documentation.
