export type SearchEntityType =
  | "person" | "content" | "hashtag" | "sound"
  | "topic" | "place" | "live" | "generic";

export type SearchTab =
  | "all" | "top" | "people" | "videos" | "posts"
  | "hashtags" | "sounds" | "topics" | "live" | "places";

export interface SearchRequest {
  query: string;
  tab?: SearchTab;
  pageSize?: number;
  cursor?: string | null;
}

export interface SearchResult {
  id: string;
  entityType: SearchEntityType;
  title: string;
  subtitle: string;
  score: number;
  queryScore: number;
  personalScore: number;
  qualityScore: number;
  popularityScore: number;
  freshnessScore: number;
  trendScore: number;
  imageUrl: string;
  creatorId: string;
  contentUrl: string;
  audioTrackId: string;
  createdAt: string | null;
  tags: string[];
  extra: Record<string, unknown>;
}

export interface SearchIndexDocument {
  id: string;
  entityType: SearchEntityType;
  title: string;
  subtitle: string;
  text: string;
  imageUrl: string;
  creatorId: string;
  contentUrl: string;
  audioTrackId: string;
  tags: string[];
  topicIds: string[];
  location: string;
  language: string;
  region: string;
  visibility: string;
  eligible: boolean;
  safetyStatus: string;
  isLive: boolean;
  views: number;
  likes: number;
  saves: number;
  followers: number;
  posts: number;
  algorithmScore: number;
  trendScore: number;
  createdAt: string | null;
  updatedAt: string | null;
  searchIndexVersion: number;
  textVector?: number[];
}

export interface SearchIndexEvent {
  eventId: string;
  operation: "upsert" | "delete";
  document?: SearchIndexDocument;
  entityType: SearchEntityType;
  entityId: string;
  version: number;
  occurredAt: string;
}

export interface AuthenticatedUser {
  uid: string;
}
