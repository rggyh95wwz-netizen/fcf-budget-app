# FCF Budget & Löhne – App

Web-App für Budget und Auszahlungen der Trainer/innen und Funktionär/innen des FC Frauenfeld.

**App öffnen:** https://rggyh95wwz-netizen.github.io/fcf-budget-app/

Dieses Repo enthält **nur die App, keine Daten**. Die Daten liegen als CSV-Dateien im privaten Repo `fcf-budget`.
Beim Öffnen meldet man sich mit einem persönlichen GitHub-Zugangsschlüssel an. Die App liest die Daten aus `fcf-budget` und speichert jede Änderung dort als Commit.
Ohne Zugang zum privaten Repo sieht man nur die Anmeldeseite.

## Zugangsschlüssel

- **Besitzer/in des Repos:** [Fine-grained Token](https://github.com/settings/personal-access-tokens/new) → Repository access *Only select repositories* → `fcf-budget` → Permissions *Contents: Read and write*.
- **Kolleg/innen** (auf `fcf-budget` als Collaborator eingeladen): [Classic Token](https://github.com/settings/tokens/new?scopes=repo&description=FCF%20Budget) mit Scope `repo`.

Der Schlüssel wird nur im eigenen Browser gespeichert ("Abmelden" löscht ihn).

## Entwicklung

`index.html` ist die ganze App (HTML, CSS, JavaScript, keine Abhängigkeiten). Änderungen hier werden über GitHub Pages veröffentlicht.
