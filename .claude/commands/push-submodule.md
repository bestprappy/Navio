# Push Submodule + Update Parent Pointer

Push the current submodule's changes to GitHub, then walk up and update every parent repo's submodule pointer.

## Steps

1. Identify which submodule I'm currently working in (check the working directory path).
2. Commit any uncommitted changes in the submodule if the user hasn't already.
3. Push the submodule to its remote (`origin main`).
4. Move to the immediate parent repo and stage + commit the updated submodule pointer.
5. Push the parent repo.
6. If the parent is itself a submodule (e.g. `server/` inside `Navio/`), repeat steps 4–5 for the umbrella repo.

Always restore remote URLs to the token-free HTTPS form after pushing.
