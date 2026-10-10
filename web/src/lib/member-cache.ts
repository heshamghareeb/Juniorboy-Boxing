import { collection, doc, documentId, getDoc, getDocs, limit, query, where } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { db } from './firebase';

export type MemberSummary = {
  uid: string;
  fullName?: string;
  lastName?: string;
  childName?: string;
  email?: string;
  phone?: string;
  sessionsRemaining?: number;
  sessionsReserved?: number;
  privateSessionsRemaining?: number;
  groupSessionsRemaining?: number;
  duoSessionsRemaining?: number;
};

// In-memory cache across admin components
const profileCache = new Map<string, MemberSummary | null>();
const pendingFetches = new Map<string, Promise<MemberSummary | null>>();

// Prefers the name the member chose themselves (participant name) over the
// account's full name, which is often just whatever their Google account set.
export function formatMemberName(fullName?: string, lastName?: string, childName?: string): string {
  const chosen = (childName || '').trim();
  if (chosen) return chosen;
  const first = (fullName || '').trim();
  const last = (lastName || '').trim();
  if (!last) return first;
  if (!first) return last;
  if (first.toLowerCase().endsWith(last.toLowerCase())) return first;
  return `${first} ${last}`;
}

/**
 * Fetch a single user profile from users/{uid} with caching
 */
export async function getMemberProfile(uid: string): Promise<MemberSummary | null> {
  if (!uid) return null;
  if (profileCache.has(uid)) return profileCache.get(uid) || null;
  if (pendingFetches.has(uid)) return pendingFetches.get(uid)!;

  const promise = (async () => {
    try {
      const snap = await getDoc(doc(db, 'users', uid));
      if (snap.exists()) {
        const data = snap.data();
        const profile: MemberSummary = {
          uid,
          fullName: data.fullName,
          lastName: data.lastName,
          childName: data.childName,
          email: data.email,
          phone: data.phone,
          sessionsRemaining: data.sessionsRemaining,
          sessionsReserved: data.sessionsReserved,
          privateSessionsRemaining: data.privateSessionsRemaining,
          groupSessionsRemaining: data.groupSessionsRemaining,
          duoSessionsRemaining: data.duoSessionsRemaining,
        };
        profileCache.set(uid, profile);
        return profile;
      } else {
        profileCache.set(uid, null);
        return null;
      }
    } catch {
      profileCache.set(uid, null);
      return null;
    } finally {
      pendingFetches.delete(uid);
    }
  })();

  pendingFetches.set(uid, promise);
  return promise;
}

/**
 * Batch fetch profiles from users/{uid} in chunks of 10 using documentId() in queries,
 * falling back to individual getDoc if needed. Caches per UID.
 */
export async function fetchMemberProfiles(uids: string[]): Promise<Record<string, MemberSummary>> {
  const unique = [...new Set(uids.filter(Boolean))];
  const missing = unique.filter((uid) => !profileCache.has(uid));

  if (missing.length > 0) {
    const chunks: string[][] = [];
    for (let i = 0; i < missing.length; i += 10) {
      chunks.push(missing.slice(i, i + 10));
    }

    await Promise.all(
      chunks.map(async (chunk) => {
        try {
          const q = query(collection(db, 'users'), where(documentId(), 'in', chunk));
          const snap = await getDocs(q);
          const found = new Set<string>();
          snap.forEach((d) => {
            found.add(d.id);
            const data = d.data();
            profileCache.set(d.id, {
              uid: d.id,
              fullName: data.fullName,
              lastName: data.lastName,
              childName: data.childName,
              email: data.email,
              phone: data.phone,
              sessionsRemaining: data.sessionsRemaining,
              sessionsReserved: data.sessionsReserved,
              privateSessionsRemaining: data.privateSessionsRemaining,
              groupSessionsRemaining: data.groupSessionsRemaining,
              duoSessionsRemaining: data.duoSessionsRemaining,
            });
          });
          for (const id of chunk) {
            if (!found.has(id)) {
              profileCache.set(id, null);
            }
          }
        } catch {
          // Fallback to getDoc for each item in chunk
          await Promise.all(
            chunk.map(async (id) => {
              try {
                const snap = await getDoc(doc(db, 'users', id));
                if (snap.exists()) {
                  const data = snap.data();
                  profileCache.set(id, {
                    uid: id,
                    fullName: data.fullName,
                    lastName: data.lastName,
                    childName: data.childName,
                    email: data.email,
                    phone: data.phone,
                    sessionsRemaining: data.sessionsRemaining,
                    sessionsReserved: data.sessionsReserved,
                    privateSessionsRemaining: data.privateSessionsRemaining,
                    groupSessionsRemaining: data.groupSessionsRemaining,
                    duoSessionsRemaining: data.duoSessionsRemaining,
                  });
                } else {
                  profileCache.set(id, null);
                }
              } catch {
                profileCache.set(id, null);
              }
            })
          );
        }
      })
    );
  }

  const result: Record<string, MemberSummary> = {};
  for (const uid of unique) {
    const val = profileCache.get(uid);
    if (val) {
      result[uid] = val;
    }
  }
  return result;
}

/**
 * Searches users by email or fullName prefix to help resolve member filter text.
 */
export async function searchMemberUids(text: string): Promise<string[]> {
  const trimmed = text.trim();
  if (!trimmed) return [];
  const results = new Set<string>();

  // Check in-memory cache first
  for (const [uid, profile] of profileCache.entries()) {
    if (!profile) continue;
    const name = formatMemberName(profile.fullName, profile.lastName, profile.childName).toLowerCase();
    const email = (profile.email || '').toLowerCase();
    const q = trimmed.toLowerCase();
    if (name.includes(q) || email.includes(q) || uid.toLowerCase() === q) {
      results.add(uid);
    }
  }

  // If text contains @, search by email
  if (trimmed.includes('@')) {
    try {
      const snap = await getDocs(
        query(collection(db, 'users'), where('email', '==', trimmed.toLowerCase()), limit(5))
      );
      snap.forEach((d) => {
        results.add(d.id);
        const data = d.data();
        profileCache.set(d.id, {
          uid: d.id,
          fullName: data.fullName,
          lastName: data.lastName,
          childName: data.childName,
          email: data.email,
          phone: data.phone,
        });
      });
    } catch {}
  } else {
    // Search by fullName prefix
    try {
      const snap = await getDocs(
        query(
          collection(db, 'users'),
          where('fullName', '>=', trimmed),
          where('fullName', '<=', trimmed + '\uf8ff'),
          limit(10)
        )
      );
      snap.forEach((d) => {
        results.add(d.id);
        const data = d.data();
        profileCache.set(d.id, {
          uid: d.id,
          fullName: data.fullName,
          lastName: data.lastName,
          childName: data.childName,
          email: data.email,
          phone: data.phone,
        });
      });
    } catch {}
  }

  return [...results];
}

/**
 * Hook to batch-fetch and cache member summaries for an array of uids
 */
export function useMemberProfiles(uids: (string | undefined | null)[]): Record<string, MemberSummary> {
  const [profiles, setProfiles] = useState<Record<string, MemberSummary>>(() => {
    const initial: Record<string, MemberSummary> = {};
    for (const u of uids) {
      if (u && profileCache.has(u)) {
        const val = profileCache.get(u);
        if (val) initial[u] = val;
      }
    }
    return initial;
  });

  const idsKey = [...new Set(uids.filter(Boolean))].sort().join(',');

  useEffect(() => {
    let active = true;
    const list = [...new Set(uids.filter((u): u is string => Boolean(u)))];
    if (!list.length) return;

    fetchMemberProfiles(list).then((res) => {
      if (active) {
        setProfiles((prev) => ({ ...prev, ...res }));
      }
    });

    return () => {
      active = false;
    };
  }, [idsKey]);

  return profiles;
}
