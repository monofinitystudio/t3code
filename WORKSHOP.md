# House T3 workshop

This checkout is **our** T3 Code (`monofinitystudio/t3code`), not the Nightly app you chat in.

| Role                         | Where                                                   | Do not                         |
| ---------------------------- | ------------------------------------------------------- | ------------------------------ |
| Agent host (this T3 Nightly) | port **3773**, data `~/.t3/userdata`                    | stop it, or write its database |
| Workshop (the T3 we edit)    | port **3873**, web **5733**, data `~/.t3/syqo-fork-dev` | point it at `~/.t3/userdata`   |

Repo: `C:\p\t3code`. Git: `origin` = our fork, `upstream` = `pingdotgg/t3code`.

## Desktop shortcut

**T3 Workshop** on the Desktop starts the workshop if it is down, focuses Nightly, and opens the workshop web preview.

## Restart the thing you are testing

Do not kill processes by name. Use the owner of port 3873:

```powershell
pwsh -NoProfile -File C:\p\t3code\scripts\workshop-dev.ps1 status
pwsh -NoProfile -File C:\p\t3code\scripts\workshop-dev.ps1 restart
```

Wait until `GET http://127.0.0.1:3873/.well-known/t3/environment` returns 200. Nightly on 3773 must still be up.

## Tests

```powershell
vp test run <files you touched>
```

No repo-wide `vp check` / `vp run -r test` unless asked. See `AGENTS.md`.

## Pull official T3

```powershell
git fetch upstream
git merge upstream/main
```
