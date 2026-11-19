# Firmowy Mózg

🇬🇧 [English version](README.md)

Asystent AI, który zna dokumenty firmy. Pracownik pyta na Telegramie i w kilka sekund dostaje odpowiedź, opartą tylko na plikach firmy, z podanym źródłem. Jeśli odpowiedzi nie ma w dokumentach, pytanie trafia do szefa, zamiast żeby bot coś zmyślił.

Zbudowałem go w n8n z OpenAI i Supabase (PostgreSQL + pgvector). To system RAG (Retrieval-Augmented Generation).

## Problem

W każdej firmie jest jedna osoba, która wie wszystko: ceny, procedury, zasady urlopów. Wszyscy chodzą do niej z pytaniami. Kiedy jej nie ma, nikt nic nie wie, a nowi pracownicy ciągle odrywają innych od pracy tymi samymi pytaniami.

## Co robi

- **Sam uczy się dokumentów.** Wrzucasz PDF do folderu na Google Drive i po minucie jest w bazie wiedzy.
- **Czyta też skany.** Jeśli PDF to sam obrazek, tekst odczytuje darmowy OCR Google Drive.
- **Trzyma jedną wersję każdego pliku.** Nowy cennik usuwa stary, więc bot nigdy nie poda nieaktualnej ceny.
- **Odpowiada na Telegramie** prostym językiem, ze źródłem na końcu.
- **Szuka po znaczeniu, a nie po słowach.** „Ile za założenie klimy?” znajdzie „montaż klimatyzacji”.
- **Nie zmyśla.** Gdy odpowiedzi brakuje, pracownik dostaje informację, a szef pytanie na Telegramie.
- **Pamięta rozmowę** („Ile kosztuje przegląd?” → „A w sobotę?”).
- **Liczy ceny** z dopłatami i rabatami i pokazuje obliczenie.

## Jak to działa

```
MODUŁ 1 – nauka dokumentów
Nowy plik na Google Drive (sprawdzane co minutę)
  → pobierz → wyciągnij tekst → posprzątaj tekst (JavaScript: stopki, numery stron, metadane)
  → czy tekst OK?
       tak → gotowy tekst
       nie → OCR: kopia jako Google Doc → eksport tekstu → usunięcie kopii → czy tekst OK?
                 tak → gotowy tekst
                 nie → alert na Telegram do szefa (nieczytelny plik)
  → gotowy tekst → usuń stare kawałki tego pliku (SQL) → pocięcie na kawałki
  → embeddingi (OpenAI) → zapis do Supabase

MODUŁ 2 – pytania i odpowiedzi
Wiadomość na Telegramie
  → agent AI (gpt-4.1-mini + pamięć rozmowy)
       używa narzędzia „baza_wiedzy”: 5 najbliższych kawałków z Supabase
  → czy w odpowiedzi jest [ESKALACJA]?
       nie → odpowiedź dla pracownika ze źródłem
       tak → informacja dla pracownika + pytanie do szefa
```

## Najważniejsze ustawienia

| Ustawienie | Wartość | Dlaczego |
| --- | --- | --- |
| Model czatu | gpt-4.1-mini, temperatura 0.2 | Tani, szybki, niska temperatura = bez zgadywania |
| Embeddingi | text-embedding-3-small (1536 liczb) | Ten sam model dla dokumentów i pytań |
| Kawałek / zakładka | 800 / 150 znaków | Jeden temat na kawałek, nic nie ginie na granicy |
| Wyniki na pytanie | 5 kawałków | Wystarczy kontekstu, niski koszt |
| Pamięć | 6 ostatnich wymian na czat | Działają pytania uzupełniające |
| Koszt | ok. 2700 tokenów na pytanie | Ułamek grosza |

## Jak chronię się przed złymi odpowiedziami

1. W instrukcji agent ma odpowiadać tylko na podstawie dokumentów.
2. Gdy odpowiedzi brakuje, AI musi napisać znacznik `[ESKALACJA]`.
3. Nie zakładam, że AI zawsze posłucha, więc warunek IF sprawdza, czy znacznik jest gdziekolwiek w odpowiedzi (`contains`, nie `starts with`).
4. Każda odpowiedź kończy się źródłem.
5. Wiadomość do pracownika przy „nie wiem” to stały tekst, a nie tekst od AI.

Przetestowałem to pytaniem o pensję, której nie ma w żadnym dokumencie. Bot nie wymyślił kwoty, a pytanie trafiło do szefa.

## Repozytorium

```
workflow/01_firmowy-mozg.json      workflow n8n (import do n8n)
sql/01_vector_store.sql            tabela, pgvector i funkcja wyszukiwania
sql/02_delete_file_chunks.sql      usuwanie starej wersji pliku
sql/03_useful_queries.sql          sprawdzanie bazy wiedzy
sample-docs/                       dokumenty fikcyjnej firmy (KlimaPro Serwis)
```

Przykładowe dokumenty opisują wymyśloną firmę od klimatyzacji. Wszystkie dane kontaktowe w nich są fałszywe.

## Uruchomienie

1. **Supabase:** załóż projekt i uruchom w SQL Editor pliki `sql/01_vector_store.sql` i `sql/02_delete_file_chunks.sql`.
2. **Telegram:** załóż bota przez @BotFather i skopiuj token.
3. **Google Drive:** utwórz folder na dokumenty.
4. **n8n:** zaimportuj `workflow/01_firmowy-mozg.json` i dodaj credentiale: OpenAI, Supabase (klucz service role), Google Drive OAuth2 i Telegram.
5. Podmień w workflow:
   - `YOUR_PROJECT_REF` w klocku „Usuń starą wersję”: adres Twojego projektu Supabase,
   - `YOUR_GOOGLE_DRIVE_FOLDER_ID` w „Nowy plik w folderze”: Twój folder,
   - `YOUR_TELEGRAM_CHAT_ID` w „Powiadom szefa” i „Alert – nieczytelny plik”: chat ID szefa.
6. Opublikuj workflow i wrzuć do folderu pliki z `sample-docs/`.
7. Zapytaj bota: *„Ile kosztuje montaż klimatyzacji?”*

Nigdy nie wpisuj kluczy API do pliku workflow ani do tego repozytorium. Ich miejsce jest tylko w credentialach n8n.

## Co dodałbym dalej

- Automatyczne ponawianie prób i workflow błędów z alertem na Telegram
- Uprawnienia według działów (np. dokumenty kadrowe niewidoczne dla techników)
- Zestaw pytań testowych sprawdzany po każdej zmianie
- Zapisywanie odpowiedzi szefa z powrotem do bazy wiedzy
- Pliki Word i Google Docs, nie tylko PDF

## Technologie

n8n · OpenAI (gpt-4.1-mini, text-embedding-3-small) · Supabase (PostgreSQL + pgvector) · SQL · JavaScript · Google Drive API · Telegram Bot API

## Licencja

MIT, zobacz [LICENSE](LICENSE).
