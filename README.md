# Firmowy Mózg – Company Brain

🇵🇱 [Wersja polska](README.pl.md)

An AI assistant that knows your company documents. Employees ask a question on Telegram and get an answer in a few seconds, based only on the company's own files, with the source file named. If the answer is not in the documents, the question goes to the owner instead of the bot making something up.

I built it in n8n with OpenAI and Supabase (PostgreSQL + pgvector). It is a RAG (Retrieval-Augmented Generation) system.

## The problem

In every company there is one person who knows everything: prices, procedures, holiday rules. Everyone goes to them with questions. When that person is away, nobody knows anything, and new employees keep interrupting others for the same answers.

## What it does

- **Learns documents by itself.** Drop a PDF into a Google Drive folder and within a minute it is in the knowledge base.
- **Reads scans too.** If a PDF is only an image, Google Drive OCR reads the text for free.
- **Keeps one version of each file.** Uploading a new price list removes the old one, so the bot never gives an outdated price.
- **Answers on Telegram** in plain Polish, with the source file at the end.
- **Searches by meaning, not by exact words.** "How much to install AC?" finds "air conditioning installation".
- **Does not make things up.** When the answer is missing, the employee is told so and the owner gets the question on Telegram.
- **Remembers the conversation** ("How much is a service?" → "And on Saturday?").
- **Calculates prices** with surcharges and discounts and shows the calculation.

## How it works

```
MODULE 1 – learning documents
New file on Google Drive (checked every minute)
  → download → extract text → clean text (JavaScript: footers, page numbers, metadata)
  → text OK?
       yes → ready text
       no  → OCR: copy as Google Doc → export text → delete the copy → text OK?
                 yes → ready text
                 no  → Telegram alert to the owner (unreadable file)
  → ready text → delete old chunks of this file (SQL) → split into chunks
  → embeddings (OpenAI) → save to Supabase

MODULE 2 – questions and answers
Telegram message
  → AI agent (gpt-4.1-mini + conversation memory)
       uses the tool "baza_wiedzy": the 5 closest chunks from Supabase
  → does the answer contain [ESKALACJA]?
       no  → reply to the employee with the source
       yes → tell the employee + send the question to the owner
```

## Key settings

| Setting | Value | Why |
| --- | --- | --- |
| Chat model | gpt-4.1-mini, temperature 0.2 | Cheap, fast, low temperature = no guessing |
| Embeddings | text-embedding-3-small (1536 numbers) | Same model for documents and questions |
| Chunk size / overlap | 800 / 150 characters | One topic per chunk, nothing lost at the edges |
| Results per question | 5 chunks | Enough context, low cost |
| Memory | last 6 exchanges per Telegram chat | Follow-up questions work |
| Cost | about 2,700 tokens per question | A fraction of a cent |

## How I prevent wrong answers

1. The agent's instructions say: answer only from the documents.
2. If the answer is missing, the AI must reply with the `[ESKALACJA]` marker.
3. I don't trust the AI to always follow that, so an IF node checks whether the marker appears anywhere in the reply (`contains`, not `starts with`).
4. Every answer ends with the source file.
5. The message to the employee in the "I don't know" case is fixed text, not AI text.

I tested it with a question about salaries, which is not in any document. The bot did not invent a number and the question reached the owner.

## Repository

```
workflow/01_firmowy-mozg.json      n8n workflow (import into n8n)
sql/01_vector_store.sql            table, pgvector and the search function
sql/02_delete_file_chunks.sql      removes the old version of a file
sql/03_useful_queries.sql          checks of the knowledge base
sample-docs/                       documents of a fictional company (KlimaPro Serwis)
```

The sample documents describe a made-up air-conditioning service company. All contact details in them are fake.

## Setup

1. **Supabase:** create a project and run `sql/01_vector_store.sql` and `sql/02_delete_file_chunks.sql` in the SQL Editor.
2. **Telegram:** create a bot with @BotFather and copy its token.
3. **Google Drive:** create a folder for the documents.
4. **n8n:** import `workflow/01_firmowy-mozg.json` and add credentials: OpenAI, Supabase (service role key), Google Drive OAuth2 and Telegram.
5. Replace the placeholders in the workflow:
   - `YOUR_PROJECT_REF` in the "Usuń starą wersję" node: your Supabase project address,
   - `YOUR_GOOGLE_DRIVE_FOLDER_ID` in "Nowy plik w folderze": your folder,
   - `YOUR_TELEGRAM_CHAT_ID` in "Powiadom szefa" and "Alert – nieczytelny plik": the owner's chat ID.
6. Publish the workflow and drop the files from `sample-docs/` into the folder.
7. Ask the bot: *"Ile kosztuje montaż klimatyzacji?"*

Never put API keys in the workflow file or in this repository. They belong only in n8n credentials.

## What I would add next

- Automatic retries and an error workflow with Telegram alerts
- Permissions per department (for example, HR documents hidden from technicians)
- A set of test questions checked after every change
- Saving the owner's answers back into the knowledge base
- Word and Google Docs files, not only PDF

## Tech stack

n8n · OpenAI (gpt-4.1-mini, text-embedding-3-small) · Supabase (PostgreSQL + pgvector) · SQL · JavaScript · Google Drive API · Telegram Bot API

## License

MIT, see [LICENSE](LICENSE).
