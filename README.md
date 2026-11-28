# FCF Budget & Löhne – App

Web-App für Budget und Auszahlungen der Trainer/innen und Funktionär/innen des FC Frauenfeld.

**App öffnen:** https://rggyh95wwz-netizen.github.io/fcf-budget-app/

Dieses Repo enthält **nur die App, keine Daten**. Die Daten liegen in einer Supabase-Datenbank.
Man meldet sich mit E-Mail und einem Code per Mail an. Was jemand sieht und ändern darf, bestimmt die Rolle (Admin, Sportchef, Trainer).
Die Regeln setzt die Datenbank durch (Row Level Security), siehe [`supabase/schema.sql`](supabase/schema.sql).

- Einrichtung: [`supabase/EINRICHTEN.md`](supabase/EINRICHTEN.md)
- Sicherung: jede Nacht als CSV ins private Repo `fcf-budget`

## Entwicklung

`index.html` ist die ganze App (HTML, CSS, JavaScript, keine Abhängigkeiten). Änderungen hier werden über GitHub Pages veröffentlicht.
Die früheren Varianten (GitHub-Schlüssel, lokaler Ordner) funktionieren nur, solange in der App kein Supabase-Projekt eingetragen ist.
