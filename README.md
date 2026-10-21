# oqta

Source of [kacapek.dev](https://kacapek.dev) (`site/`) and [pro.kacapek.dev](https://pro.kacapek.dev) (`pro/`). Plain HTML.

- preview: `python3 -m http.server 8090 --directory site`
- deploy: `git push pi main` — the Pi rebuilds both sites from the pushed commit

One-time setup on a new machine: `git remote add pi k@176.62.231.116:oqta.git`
