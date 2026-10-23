# oqta

Source of [kacapek.dev](https://kacapek.dev) (`site/`), [pro.kacapek.dev](https://pro.kacapek.dev) (`pro/`) and [relay.kacapek.dev](https://relay.kacapek.dev) (`relay/`). Plain HTML.

- preview: `python3 -m http.server 8090 --directory site`
- deploy: `git push pi main` — the Pi rebuilds every site from the pushed commit

One-time setup on a new machine: `git remote add pi k@176.62.231.116:oqta.git`
