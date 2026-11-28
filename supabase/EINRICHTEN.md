# Supabase einrichten (einmalig, ca. 30 Minuten)

Danach melden sich alle mit E-Mail und Code an. Was jemand sieht und ändern darf, bestimmt die Rolle:

| Rolle | Sieht | Darf ändern |
|---|---|---|
| **Admin** | alles | alles, inkl. Auszahlung, Einstellungen, Benutzer |
| **Sportchef** | alles ausser Adresse/IBAN/AHV-Nr. | Budgets, Zuordnungen, Erfassung, Stammdaten, Saisons |
| **Trainer** | eigene Teams (Teambudget, wer im Team ist), eigene Ansätze, eigene Belege | eigene Einheiten/Einsätze (bis zur Auszahlung), eigene Adresse/IBAN |

Die Regeln setzt die Datenbank durch, nicht nur die App.

## 1. Projekt anlegen
1. https://supabase.com → **Start your project** (Anmeldung mit GitHub geht).
2. **New project**: Name `fcf-budget`, Region **Zurich** (falls angeboten, sonst Frankfurt), Datenbank-Passwort generieren und sicher ablegen. Plan **Free**.

## 2. Datenbank und Daten
1. Links **SQL Editor** → **New query**.
2. Den ganzen Inhalt von [`schema.sql`](https://raw.githubusercontent.com/rggyh95wwz-netizen/fcf-budget-app/main/supabase/schema.sql) einfügen → **Run**.
3. Neue Query: den ganzen Inhalt von `supabase/import.sql` aus dem **privaten** Repo fcf-budget einfügen (auf GitHub öffnen → Button "Raw" bzw. "Copy raw file") → **Run**.
   Das übernimmt alle Personen, Teams, Saisons und Budgets. Alle 74 Personen mit E-Mail werden als **Trainer** eingetragen, Joel Ruh als **Admin** (mit seiner E-Mail aus den Personendaten).

## 3. Anmeldung per Code
1. **Authentication → Sign In / Providers → Email**: aktiv lassen.
2. **Authentication → Emails → Templates**: in den Vorlagen **Magic Link** und **Confirm signup** den Text ersetzen, z. B.:
   ```
   <h2>FCF Budget & Löhne</h2>
   <p>Dein Anmeldecode: <b>{{ .Token }}</b></p>
   <p>Der Code ist eine Stunde gültig.</p>
   ```
   Wichtig ist `{{ .Token }}`, sonst kommt ein Link statt eines Codes.
3. **Mailversand**: Der eingebaute Versand reicht zum Testen, schafft aber nur wenige Mails pro Stunde.
   Für alle Trainer unter **Authentication → Emails → SMTP Settings** einen eigenen Versand eintragen, z. B. ein Gmail- oder Vereins-Mailkonto
   (Gmail: Host `smtp.gmail.com`, Port `465`, Benutzer = Gmail-Adresse, Passwort = ein "App-Passwort" aus dem Google-Konto).

## 4. App verbinden
**Project Settings → API Keys** (bzw. "Data API"): **Project URL** und den **anon / publishable key** kopieren.
Diese beiden Werte sind öffentlich (kein Geheimnis) und kommen fest in die App. Bis dahin: in der App "Erweitert" aufklappen und einfügen.

Nicht weitergeben: den **service_role / secret key**. Der gehört nur in Schritt 5.

## 5. Nächtliche Sicherung ins Git-Repo
1. Supabase: **Project Settings → API Keys** → den **service_role / secret key** kopieren.
2. GitHub, Repo **fcf-budget** → **Settings → Secrets and variables → Actions → New repository secret**:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_SERVICE_KEY` = service_role / secret key
3. **Actions → Nächtliche Sicherung aus Supabase → Run workflow** zum Testen.
   Danach läuft sie jede Nacht und schreibt alle Daten als CSV nach `daten/`. Das hält auch das Gratis-Projekt aktiv.

## 6. Rollen vergeben
In der App als Admin: **Einstellungen & Daten → Benutzer & Rollen**. Sportchefs auf "Sportchef" stellen, weitere Zugänge mit "+ Zugang".
Trainer sehen automatisch die Teams, in denen sie eine Zuordnung haben.

Ab jetzt ist Supabase die einzige Quelle. Die CSV-Dateien im Repo sind nur noch die Sicherung und werden nicht mehr direkt bearbeitet.
