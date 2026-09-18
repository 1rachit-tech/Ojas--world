import type { SearchResult } from "./types";

function normalizedQuery(value: string): string {
  return value
    .normalize("NFKC")
    .trim()
    .toLowerCase()
    .replace(/^[@#]/, "");
}

function matches(value: string, query: string): boolean {
  const q = normalizedQuery(query);
  if (!q) return true;
  return value.toLowerCase().includes(q);
}

export function projectEntityTab(
  results: SearchResult[],
  tab: string,
  query: string,
): SearchResult[] {
  if (tab === "live") return results;

  if (!["hashtags", "sounds", "topics", "places"].includes(tab)) {
    return results;
  }

  const output: SearchResult[] = [];
  const seen = new Set<string>();

  const add = (result: SearchResult) => {
    const key = result.entityType + ":" + result.id;
    if (seen.has(key)) return;
    seen.add(key);
    output.push(result);
  };

  for (const source of results) {
    if (tab === "hashtags") {
      for (const tag of source.tags) {
        if (!matches(tag, query)) continue;
        const clean = tag.replace(/^#/, "");
        add({
          ...source,
          id: clean,
          entityType: "hashtag",
          title: "#" + clean,
          subtitle: "Hashtag",
          extra: {
            ...source.extra,
            sourceContentId: source.id,
          },
        });
      }
    }

    if (tab === "sounds" && source.audioTrackId) {
      if (matches(source.audioTrackId, query)) {
        add({
          ...source,
          id: source.audioTrackId,
          entityType: "sound",
          title: source.audioTrackId,
          subtitle: "Sound",
          extra: {
            ...source.extra,
            sourceContentId: source.id,
          },
        });
      }
    }

    if (tab === "topics") {
      const topicIds = source.extra.topicIds;
      if (!Array.isArray(topicIds)) continue;

      for (const topic of topicIds) {
        if (typeof topic !== "string" || !matches(topic, query)) {
          continue;
        }

        add({
          ...source,
          id: topic,
          entityType: "topic",
          title: topic,
          subtitle: "Topic",
          extra: {
            ...source.extra,
            sourceContentId: source.id,
          },
        });
      }
    }

    if (tab === "places" && source.extra.location) {
      const place = String(source.extra.location);
      if (!matches(place, query)) continue;

      add({
        ...source,
        id: place,
        entityType: "place",
        title: place,
        subtitle: "Place",
        extra: {
          ...source.extra,
          sourceContentId: source.id,
        },
      });
    }
  }

  return output;
}
