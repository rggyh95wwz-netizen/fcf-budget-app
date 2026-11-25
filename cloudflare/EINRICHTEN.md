# Anmeldung mit E-Mail und Einmalcode (Cloudflare)

Kolleg/innen öffnen einen Link, geben ihre E-Mail ein, bekommen einen Code per Mail und sind in der App.
Kein GitHub-Konto nötig. Den GitHub-Schlüssel kennt nur der Cloudflare-Dienst ("Worker").
Kosten: Gratisplan (Workers bis 100'000 Aufrufe/Tag, Zero Trust bis 50 Personen).

Einmalige Einrichtung, ca. 20 Minuten. Die Menünamen bei Cloudflare können leicht abweichen.

## 1. Konto
Auf https://dash.cloudflare.com/sign-up ein Konto erstellen.

## 2. Worker anlegen
1. Links **Workers & Pages** (bzw. "Compute") → **Create** → **Worker** → "Hello World" → Name `fcf-budget` → **Deploy**.
2. **Edit code** → alles löschen → den ganzen Inhalt von [`worker.js`](worker.js) einfügen → **Deploy**.

## 3. GitHub-Schlüssel für den Worker
1. Auf GitHub einen neuen Fine-grained Token erstellen: nur Repo **fcf-budget**, **Contents: Read and write**, Ablauf z. B. 1 Jahr.
2. Im Worker → **Settings → Variables and Secrets → Add** → Typ **Secret**, Name `GH_TOKEN`, Wert = Token → speichern.

## 4. Anmeldung einschalten (Cloudflare Access)
1. Im Worker → **Settings → Domains & Routes** → bei `workers.dev` **Cloudflare Access** aktivieren.
   Beim ersten Mal richtet Cloudflare "Zero Trust" ein: Team-Name wählen (z. B. `fcfrauenfeld`) und den **Free**-Plan.
2. Cloudflare zeigt danach **AUD** (lange Zeichenkette) an. Kopieren.
3. Im Worker → **Settings → Variables and Secrets** zwei Variablen (Typ Text) anlegen:
   - `TEAM_DOMAIN` = `<team-name>.cloudflareaccess.com` (z. B. `fcfrauenfeld.cloudflareaccess.com`)
   - `POLICY_AUD` = die kopierte AUD
   → **Deploy**.

## 5. Wer darf rein?
**Zero Trust** (https://one.dash.cloudflare.com) → **Access → Applications** → die Anwendung zum Worker → **Policies** →
Regel bearbeiten: *Include* → **Emails** → alle erlaubten E-Mail-Adressen eintragen → speichern.
Login-Methode: **Settings → Authentication → One-time PIN** muss aktiv sein (Standard).

Neue Person: Adresse hier ergänzen. Person entfernen: Adresse löschen.

## 6. Fertig
Link: `https://fcf-budget.<dein-konto>.workers.dev`
E-Mail eingeben → Code aus der Mail eingeben → App öffnet sich mit den Daten. Jede Änderung wird als Commit mit der E-Mail der Person gespeichert.

Sicherheit: Der Worker prüft bei jeder Anfrage das signierte Anmelde-Token von Cloudflare. Fehlen `TEAM_DOMAIN`/`POLICY_AUD` oder ist das Token ungültig, gibt es keinen Zugriff.
Der Worker erlaubt nur Lesen und Speichern von Dateien im Repo fcf-budget, nichts anderes.
