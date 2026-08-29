# Box XLSX handoff

## State

- Remote: `purduebox:` (existing authorized rclone Box OAuth remote).
- Destination: `purduebox:Experiments/test-files` (Box folder ID `413225701561`).
- Uploaded: 45 original XLSX files, 4.654 GiB; `rclone check` returned 45 matches and 0 differences.
- Public links: one per file, open/downloadable, `unshared_at: null` (never expires).
- Website mapping: `saved_results/tests/reports/data/box-download-links.json`.
- Production: `https://rths-viewer.vercel.app` (`rths-viewer` Vercel project).

## Upload/update

1. Use website names from `report-metadata.json -> files[*].display_name`; upload each original XLSX as `<display_name>.xlsx`. Names must be unique.
2. Stage renamed hardlinks under `.codex/` to avoid duplicating multi-GB files.
3. Upload:

```powershell
rclone copy <staging-dir> "purduebox:Experiments/test-files" --box-upload-cutoff 50Mi --transfers 4 --checkers 8 --retries 3 --low-level-retries 10
rclone check <staging-dir> "purduebox:Experiments/test-files" --one-way
```

4. Get IDs with `rclone lsjson "purduebox:Experiments/test-files" --files-only`.
5. Create/update each file link through `PUT https://api.box.com/2.0/files/<ID>?fields=id,name,shared_link`:

```json
{"shared_link":{"access":"open","unshared_at":null,"permissions":{"can_download":true}}}
```

Use the OAuth access token from the local rclone config only in memory. Run `rclone about purduebox:` first so rclone refreshes it. Never print or commit the token. Record each returned `shared_link.url` against the original MAT path in `box-download-links.json`.

## Important behavior

- Purdue blocks the official Box CLI, but the pre-authorized `purduebox:` rclone remote works.
- The collaborative `test-files` folder is owner-controlled and cannot be made public by this account's Editor role. Individual file links can be public.
- Box initially applied a 60-day expiration to public links. Always send `"unshared_at": null`, then verify all returned values are null.
- Do not deploy compact/generated XLSX substitutes. Vercel contains report assets and Box URLs only; omit the `downloads/` directory.

## Verification/deployment

```powershell
curl.exe -sS -L -o NUL -w "%{http_code}" <shared-link>  # expect 200 without cookies
vercel deploy --prod --yes                               # from a clean bundle linked to rths-viewer
```

Live page should expose 45 `a.file-download` elements, each targeting an `https://app.box.com/s/...` URL.
