import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { XMLParser } from 'https://esm.sh/fast-xml-parser@4.5.3';

type RssItem = {
  externalId?: string;
  url?: string;
  title: string;
  summary?: string;
  content?: string;
  author?: string;
  publishedAt?: string;
  language?: string;
  lat?: number;
  lng?: number;
  raw: Record<string, unknown>;
};

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing_env:${name}`);
  return v;
}

function normalizeText(s: string): string {
  return s
    .trim()
    .replaceAll(/\s+/g, ' ')
    .toLowerCase();
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function tryParseDate(value?: string): string | undefined {
  const v = (value ?? '').trim();
  if (!v) return undefined;
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return undefined;
  return d.toISOString();
}

function coerceNumber(v: unknown): number | undefined {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

function pickFirstString(...values: unknown[]): string | undefined {
  for (const v of values) {
    if (typeof v === 'string') {
      const s = v.trim();
      if (s) return s;
    }
  }
  return undefined;
}

function asArray<T>(v: T | T[] | undefined | null): T[] {
  if (v == null) return [];
  return Array.isArray(v) ? v : [v];
}

function extractRssItems(feedXml: string): RssItem[] {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '',
    removeNSPrefix: true,
    trimValues: true,
    parseTagValue: false,
  });
  const doc = parser.parse(feedXml) as Record<string, unknown>;

  const rss = doc['rss'] as Record<string, unknown> | undefined;
  const channel = rss?.['channel'] as Record<string, unknown> | undefined;
  const itemsRaw = asArray(channel?.['item'] as Record<string, unknown> | Record<string, unknown>[] | undefined);
  if (itemsRaw.length > 0) {
    return itemsRaw
      .map((it) => {
        const title = pickFirstString(it['title']) ?? '';
        const link = pickFirstString(it['link']);
        const guid = pickFirstString(it['guid'], (it['guid'] as any)?.['#text']);
        const description = pickFirstString(it['description'], it['summary']);
        const content = pickFirstString((it as any)['encoded'], it['content']);
        const author = pickFirstString(it['author'], it['creator']);
        const pub = pickFirstString(it['pubDate'], it['published'], it['updated']);
        const lat = coerceNumber(it['lat'], (it as any)['geo:lat'], (it as any)['georss:point']?.split?.(' ')?.[0]);
        const lng = coerceNumber(it['lng'], (it as any)['geo:long'], (it as any)['georss:point']?.split?.(' ')?.[1]);
        return {
          externalId: guid ?? link,
          url: link,
          title,
          summary: description,
          content,
          author,
          publishedAt: pub,
          lat,
          lng,
          raw: it,
        } satisfies RssItem;
      })
      .filter((it) => it.title.trim().length > 0);
  }

  const feed = doc['feed'] as Record<string, unknown> | undefined;
  const entries = asArray(feed?.['entry'] as Record<string, unknown> | Record<string, unknown>[] | undefined);
  return entries
    .map((it) => {
      const title = pickFirstString(it['title']) ?? '';
      const links = asArray(it['link'] as any);
      const href = pickFirstString(
        (links.find((l: any) => l?.rel === 'alternate') as any)?.href,
        (links[0] as any)?.href,
        it['link'],
      );
      const id = pickFirstString(it['id'], href);
      const summary = pickFirstString(it['summary'], (it as any)['content']?.['#text']);
      const content = pickFirstString((it as any)['content']?.['#text']);
      const author = pickFirstString((it as any)['author']?.name);
      const pub = pickFirstString(it['published'], it['updated']);
      return {
        externalId: id,
        url: href,
        title,
        summary,
        content,
        author,
        publishedAt: pub,
        raw: it,
      } satisfies RssItem;
    })
    .filter((it) => it.title.trim().length > 0);
}

async function ingestSource(
  supabase: ReturnType<typeof createClient>,
  source: { id: string; url: string; etag: string | null; last_modified: string | null; language: string | null; region_hint_path: string | null },
): Promise<{ inserted: number; fetched: boolean }> {
  const headers = new Headers();
  headers.set('user-agent', 'atalaia-news-ingest/1.0');
  if (source.etag) headers.set('if-none-match', source.etag);
  if (source.last_modified) headers.set('if-modified-since', source.last_modified);
  const resp = await fetch(source.url, { headers });
  if (resp.status === 304) {
    await supabase
      .from('news_sources')
      .update({ last_polled_at: new Date().toISOString() })
      .eq('id', source.id);
    return { inserted: 0, fetched: false };
  }
  if (!resp.ok) throw new Error(`fetch_failed:${resp.status}`);

  const xml = await resp.text();
  const items = extractRssItems(xml);
  const nowIso = new Date().toISOString();

  const rows = await Promise.all(
    items.slice(0, 80).map(async (it) => {
      const publishedIso = tryParseDate(it.publishedAt);
      const h = await sha256Hex(
        [
          normalizeText(it.title),
          normalizeText(it.summary ?? ''),
          normalizeText(it.content ?? ''),
          normalizeText(it.url ?? ''),
          normalizeText(publishedIso ?? ''),
        ].join('|'),
      );
      return {
        source_id: source.id,
        external_id: it.externalId ?? null,
        url: it.url ?? null,
        title: it.title,
        summary: it.summary ?? null,
        content: it.content ?? null,
        author: it.author ?? null,
        published_at: publishedIso ?? null,
        fetched_at: nowIso,
        content_hash: h,
        language: source.language ?? it.language ?? null,
        lat: it.lat ?? null,
        lng: it.lng ?? null,
        raw: it.raw,
      };
    }),
  );

  const { error: insertError, data } = await supabase
    .from('news_items')
    .upsert(rows, { onConflict: 'content_hash', ignoreDuplicates: true })
    .select('id');

  if (insertError) throw insertError;

  const etag = resp.headers.get('etag');
  const lastModified = resp.headers.get('last-modified');
  await supabase
    .from('news_sources')
    .update({
      last_polled_at: nowIso,
      last_success_at: nowIso,
      etag: etag ?? source.etag,
      last_modified: lastModified ?? source.last_modified,
      last_error: null,
      error_count: 0,
    })
    .eq('id', source.id);

  return { inserted: (data as any[] | null)?.length ?? 0, fetched: true };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('method_not_allowed', { status: 405 });

    const cronSecret = Deno.env.get('NEWS_CRON_SECRET');
    if (cronSecret) {
      const provided = req.headers.get('x-cron-secret') ?? '';
      if (provided !== cronSecret) return new Response('unauthorized', { status: 401 });
    }

    const supabase = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
      auth: { persistSession: false },
      global: { headers: { 'x-client-info': 'atalaia-news-cron' } },
    });

    const { data: sources, error: srcErr } = await supabase
      .from('news_sources')
      .select('id,url,etag,last_modified,language,region_hint_path,error_count')
      .eq('is_active', true)
      .eq('kind', 'rss')
      .order('updated_at', { ascending: true })
      .limit(40);

    if (srcErr) throw srcErr;

    let insertedTotal = 0;
    let fetchedTotal = 0;
    let failures = 0;

    for (const s of sources ?? []) {
      try {
        const r = await ingestSource(supabase, s as any);
        insertedTotal += r.inserted;
        if (r.fetched) fetchedTotal += 1;
      } catch (e) {
        failures += 1;
        await supabase
          .from('news_sources')
          .update({
            last_polled_at: new Date().toISOString(),
            last_error: e instanceof Error ? e.message : String(e),
            error_count: ((s as any).error_count ?? 0) + 1,
          })
          .eq('id', (s as any).id);
      }
    }

    const { data: processedItems, error: processErr } = await supabase.rpc('news_process_items', { p_limit: 300 });
    if (processErr) throw processErr;
    const { data: prayersCreated, error: prayersErr } = await supabase.rpc('news_materialize_prayers', { p_limit: 40 });
    if (prayersErr) throw prayersErr;
    const { data: notificationsSent, error: notifyErr } = await supabase.rpc('news_notify_recent_events', { p_limit: 200 });
    if (notifyErr) throw notifyErr;
    const { data: jobsProcessed, error: jobsErr } = await supabase.rpc('process_job_queue', { p_limit: 60, p_worker_id: 'news-cron' });
    if (jobsErr) throw jobsErr;

    return Response.json({
      ok: true,
      sources: (sources ?? []).length,
      sourcesFetched: fetchedTotal,
      sourcesFailed: failures,
      itemsInserted: insertedTotal,
      itemsProcessed: processedItems ?? 0,
      prayersCreated: prayersCreated ?? 0,
      notificationsSent: notificationsSent ?? 0,
      jobsProcessed: (jobsProcessed as any[] | null)?.length ?? 0,
    });
  } catch (e) {
    return Response.json({ ok: false, error: e instanceof Error ? e.message : String(e) }, { status: 500 });
  }
});
