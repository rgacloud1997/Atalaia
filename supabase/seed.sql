insert into public.news_sources (kind, name, url, language, region_hint_path, is_active)
values
  ('rss'::public.news_source_kind, 'UN News — Global', 'https://news.un.org/feed/subscribe/en/news/all/rss.xml', 'en', 'world', true),
  ('rss'::public.news_source_kind, 'ReliefWeb — Updates', 'https://reliefweb.int/updates/rss.xml', 'en', 'world', true),
  ('rss'::public.news_source_kind, 'BBC — World', 'https://feeds.bbci.co.uk/news/world/rss.xml', 'en', 'world', true),
  ('rss'::public.news_source_kind, 'G1 — Mundo', 'https://g1.globo.com/rss/g1/mundo/', 'pt', 'world', true),
  ('rss'::public.news_source_kind, 'Vatican News — World', 'https://www.vaticannews.va/en/rss.xml', 'en', 'world', true)
on conflict (url) do nothing;

