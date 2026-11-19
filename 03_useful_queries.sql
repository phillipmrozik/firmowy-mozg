-- =========================================================
-- 03. Useful queries for checking the knowledge base
-- =========================================================

-- How many chunks does each file have?
select
  metadata->>'file_name' as plik,
  count(*) as kawalki
from documents
group by metadata->>'file_name'
order by kawalki desc;

-- Which files were read with OCR (scans)?
select distinct metadata->>'file_name' as plik
from documents
where (metadata->>'ocr')::boolean = true;

-- Find chunks that mention a word (plain text search)
select metadata->>'file_name' as plik, left(content, 120) as fragment
from documents
where content ilike '%urlop%';
