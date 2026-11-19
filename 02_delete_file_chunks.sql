-- =========================================================
-- 02. Remove the old version of a file before saving the new one
-- Called from n8n: POST /rest/v1/rpc/delete_file_chunks
-- Returns how many chunks were deleted
-- =========================================================

create or replace function delete_file_chunks(p_file_name text)
returns integer
language sql
as $$
  with usuniete as (
    delete from documents
    where metadata->>'file_name' = p_file_name
    returning 1
  )
  select count(*)::int from usuniete;
$$;
