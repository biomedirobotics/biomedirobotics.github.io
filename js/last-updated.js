/* Footer date: read it from the repository's newest commit at load.
 *
 * Every page used to carry a literal date stamped by
 * scripts/stamp-last-updated.sh, because a browser cannot read the commit date
 * of a private repository — the unauthenticated GitHub API answers 404 for
 * one. The repository is public now, so the date is fetched instead, and the
 * stamped literal stays behind as the fallback.
 *
 * The literal is kept rather than replaced with document.lastModified on
 * failure: these pages are static, so lastModified is the deploy time rather
 * than the last content change, which would be wrong rather than merely stale.
 * A failed, rate-limited or JavaScript-less visit therefore still shows the
 * date its page was built with. */

(() => {
    'use strict';

    const REPO = 'biomedirobotics/biomedirobotics.github.io';
    const CACHE_KEY = 'last-updated:' + REPO;
    const CACHE_MS = 60 * 60 * 1000;

    const targets = document.querySelectorAll('[data-last-updated]');

    /* The footer shows the lab's calendar date rather than the visitor's: a
       commit made at 01:00 in Hong Kong is still the previous day in UTC.
       Built from formatToParts so the output does not depend on the format
       any one locale happens to use. */
    const isoDate = (iso) => {
        const parts = new Intl.DateTimeFormat('en-US', {
            timeZone: 'Asia/Hong_Kong',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).formatToParts(new Date(iso));

        const value = (type) => parts.find((part) => part.type === type).value;
        return `${value('year')}-${value('month')}-${value('day')}`;
    };

    const show = (iso) => {
        const text = isoDate(iso);
        targets.forEach((target) => {
            target.textContent = text;
        });
    };

    const cached = () => {
        try {
            const entry = JSON.parse(sessionStorage.getItem(CACHE_KEY));
            if (entry && Date.now() - entry.at < CACHE_MS) {
                return entry.date;
            }
        } catch (e) {
            /* no storage, or nothing cached */
        }
        return null;
    };

    /* One request per browser session per hour. The unauthenticated API allows
       60 requests an hour for an address, which a shared campus network can
       exhaust on its own, and the footer is on every page. */
    const remember = (iso) => {
        try {
            sessionStorage.setItem(CACHE_KEY, JSON.stringify({ date: iso, at: Date.now() }));
        } catch (e) {
            /* private mode: the next page simply fetches again */
        }
    };

    const latestCommit = () =>
        fetch(`https://api.github.com/repos/${REPO}/commits?per_page=1`)
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                return response.json();
            })
            .then((commits) => {
                const commit = commits && commits[0] && commits[0].commit;
                const iso = commit && commit.committer && commit.committer.date;
                if (!iso) {
                    throw new Error('unexpected response');
                }
                return iso;
            });

    if (targets.length) {
        const hit = cached();
        if (hit) {
            show(hit);
        } else {
            latestCommit()
                .then((iso) => {
                    show(iso);
                    remember(iso);
                })
                .catch(() => {
                    /* keep the date the page was built with */
                });
        }
    }
})();
