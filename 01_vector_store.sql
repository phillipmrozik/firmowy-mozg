-- =========================================================
-- 01. Vector store for Firmowy Mózg (Supabase / PostgreSQL)
-- Run once in Supabase -> SQL Editor
-- =========================================================

-- pgvector: lets PostgreSQL store and compare embeddings
create extension if not exists vector with schema extensions;

-- One row = one chunk of a company document
create table documents (
  id bigserial primary key,
  content text,            -- chunk text
  metadata jsonb,          -- file_name, file_id, source_url, ingested_at
  embedding vector(1536)   -- text-embedding-3-small returns 1536 numbers
);

-- Semantic search used by the n8n Supabase Vector Store node
create or replace function match_documents (
  query_embedding vector(1536),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;
