.pragma library

// Scoring and normalization model matching github.com/4lwayz/portwatch-vi (assets/js/scoring.js).

const MILESTONES = [
    { key: "groundwork", label: "Groundwork", at: 0 },
    { key: "loads", label: "Exe runs", at: 10 },
    { key: "boots", label: "First frame", at: 20 },
    { key: "menu", label: "Main menu", at: 30 },
    { key: "world", label: "In the world", at: 40 },
    { key: "playable", label: "Playable", at: 50 },
    { key: "complete", label: "Complete", at: 100 }
];

const TRACKS = [
    {
        key: "story",
        label: "Story progress",
        weight: 0.35,
        steps: [
            { v: 0, label: "Stuck in the opening" },
            { v: 0.1, label: "Prologue cleared" },
            { v: 0.25, label: "First missions" },
            { v: 0.4, label: "First act" },
            { v: 0.6, label: "Half the story" },
            { v: 0.85, label: "Main story to credits" },
            { v: 1, label: "100% completion" }
        ]
    },
    {
        key: "render",
        label: "Rendering",
        weight: 0.25,
        steps: [
            { v: 0, label: "Black or broken" },
            { v: 0.25, label: "Shapes drawn, unlit" },
            { v: 0.5, label: "Lit, effects missing" },
            { v: 0.75, label: "Close to console" },
            { v: 1, label: "Matches console" }
        ]
    },
    { key: "perf", label: "Performance", weight: 0.2 },
    { key: "stability", label: "Stability", weight: 0.2 }
];

const GROUNDWORK = [
    { key: "loader", label: "Loader & system libs", weight: 0.2 },
    { key: "shaders", label: "Shader translation", weight: 0.28 },
    { key: "graphics", label: "Graphics layer", weight: 0.32 },
    { key: "proven", label: "Proven on other games", weight: 0.2 }
];

const STABILITY = {
    unknown: { label: "Unknown", value: 0 },
    constant: { label: "Crashes constantly", value: 0 },
    often: { label: "Crashes often", value: 0.25 },
    sometimes: { label: "Crashes sometimes", value: 0.55 },
    rarely: { label: "Rarely crashes", value: 0.8 },
    stable: { label: "Stable", value: 1 }
};

const GPU_BRANDS = ["AMD", "NVIDIA", "Intel", "Mac"];

const LADDER = ["loads", "boots", "menu", "world", "playable"];
const TICK = {
    groundwork: 0,
    loads: 10,
    boots: 20,
    menu: 30,
    world: 40,
    playable: 50,
    complete: 100
};

function clamp01(v) {
    const n = Number(v);
    if (!Number.isFinite(n))
        return 0;
    return Math.min(1, Math.max(0, n));
}

function ladderValue(v) {
    if (v === true)
        return 1;
    if (v === false || v === null || v === undefined)
        return 0;
    return clamp01(v);
}

function groundworkFraction(gw) {
    if (!gw)
        return 0;
    let sum = 0;
    for (let i = 0; i < GROUNDWORK.length; i++) {
        const g = GROUNDWORK[i];
        sum += g.weight * clamp01(gw[g.key]);
    }
    return sum;
}

function stabilityKey(v) {
    if (typeof v !== "number")
        return STABILITY[v] ? v : "unknown";
    let best = "constant";
    const keys = Object.keys(STABILITY);
    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key === "unknown")
            continue;
        if (Math.abs(STABILITY[key].value - v) <= Math.abs(STABILITY[best].value - v) + 1e-9)
            best = key;
    }
    return best;
}

function trackValues(gta) {
    const g = gta || {};
    const stabRaw = g.stability;
    const stability = typeof stabRaw === "number"
        ? clamp01(stabRaw)
        : (STABILITY[stabRaw] || STABILITY.unknown).value;
    return {
        story: clamp01(g.story),
        render: clamp01(g.render),
        perf: clamp01((Number(g.fps) || 0) / 30),
        stability: stability
    };
}

function trackStepLabel(key, v) {
    const tr = TRACKS.find(item => item.key === key);
    if (!tr || !tr.steps)
        return "";
    const clamped = clamp01(v);
    let matched = tr.steps[0];
    for (let i = tr.steps.length - 1; i >= 0; i--) {
        if (clamped >= tr.steps[i].v) {
            matched = tr.steps[i];
            break;
        }
    }
    return matched ? matched.label : "";
}

function milestoneLabel(key) {
    const found = MILESTONES.find(m => m.key === key);
    return found ? found.label : key;
}

function scoreEffort(effort) {
    const gw = groundworkFraction(effort.groundwork);
    const gta = effort.gta || {};
    let score = TICK.loads * gw;
    let reached = "groundwork";
    let prevTick = score;

    for (let i = 0; i < LADDER.length; i++) {
        const key = LADDER[i];
        const v = ladderValue(gta[key]);
        if (v >= 1) {
            score = TICK[key];
            prevTick = score;
            reached = key;
            continue;
        }
        if (v > 0)
            score = Math.max(score, prevTick + v * (TICK[key] - prevTick));
        break;
    }

    const tracks = trackValues(gta);
    let quality = 0;
    for (let i = 0; i < TRACKS.length; i++) {
        const tr = TRACKS[i];
        quality += tr.weight * tracks[tr.key];
    }
    if (reached === "playable") {
        score = TICK.playable + quality * (TICK.complete - TICK.playable);
        if (quality >= 1)
            reached = "complete";
    }

    if (typeof effort.manualScore === "number" && Number.isFinite(effort.manualScore))
        score = Math.min(100, Math.max(0, effort.manualScore));

    return {
        score: Math.round(score * 10) / 10,
        groundwork: gw,
        reached: reached,
        reachedLabel: milestoneLabel(reached),
        tracks: tracks,
        playable: reached === "playable" || reached === "complete"
    };
}

function isPrivateBuild(effort) {
    return !(typeof effort.repo === "string" && /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(effort.repo));
}

function safeGitHubUrl(repo, branch) {
    if (typeof repo !== "string" || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo))
        return "";
    const base = "https://github.com/" + repo;
    if (branch && branch !== "main" && branch !== "master")
        return base + "/tree/" + encodeURIComponent(branch);
    return base;
}

function safeHttpsUrl(url) {
    if (typeof url === "string" && /^https:\/\//.test(url))
        return url;
    return "";
}

function formatScore(score) {
    const rounded = Math.round((Number(score) || 0) * 10) / 10;
    return String(rounded) + "%";
}

function formatCompactCount(n) {
    if (n === null || n === undefined || !Number.isFinite(Number(n)))
        return "—";
    const num = Number(n);
    if (num >= 10000)
        return Math.round(num / 1000) + "k";
    if (num >= 1000)
        return (num / 1000).toFixed(1) + "k";
    return String(Math.round(num));
}

function formatAgo(isoString, nowMs) {
    if (!isoString)
        return "";
    const parsed = Date.parse(isoString);
    if (!Number.isFinite(parsed))
        return "";
    const now = Number.isFinite(nowMs) ? nowMs : Date.now();
    const secs = Math.max(0, (now - parsed) / 1000);
    if (secs < 60)
        return "just now";
    const mins = secs / 60;
    if (mins < 60)
        return Math.round(mins) + "m ago";
    const hours = mins / 60;
    if (hours < 24)
        return Math.round(hours) + "h ago";
    const days = hours / 24;
    return Math.round(days) + "d ago";
}

function buildBreakdown(effort, scored) {
    const gta = effort.gta || {};
    const rows = [];
    if (scored.playable) {
        const fps = Number(gta.fps) || 0;
        const stabKey = stabilityKey(gta.stability);
        rows.push({
            label: "Story progress",
            valueText: trackStepLabel("story", scored.tracks.story),
            fraction: scored.tracks.story
        });
        rows.push({
            label: "Rendering",
            valueText: trackStepLabel("render", scored.tracks.render),
            fraction: scored.tracks.render
        });
        rows.push({
            label: "Performance",
            valueText: fps > 0 ? Math.round(fps) + " / 30 FPS" : "Unmeasured",
            fraction: scored.tracks.perf
        });
        rows.push({
            label: "Stability",
            valueText: (STABILITY[stabKey] || STABILITY.unknown).label,
            fraction: scored.tracks.stability
        });
        return { kind: "tracks", rows: rows };
    }
    if (effort.groundwork) {
        for (let i = 0; i < GROUNDWORK.length; i++) {
            const g = GROUNDWORK[i];
            const frac = clamp01(effort.groundwork[g.key]);
            rows.push({
                label: g.label,
                valueText: Math.round(frac * 100) + "%",
                fraction: frac
            });
        }
        return { kind: "groundwork", rows: rows };
    }
    return { kind: "none", rows: [] };
}

function verificationLabel(v) {
    if (v === "portwatch")
        return "Verified by PortWatch";
    if (v === "reproduced")
        return "Reproduced";
    return "Self-reported";
}

function normalizeGpus(raw) {
    if (!Array.isArray(raw))
        return [];
    const out = [];
    for (let i = 0; i < raw.length; i++) {
        const g = String(raw[i] || "");
        if (GPU_BRANDS.indexOf(g) !== -1 && out.indexOf(g) === -1)
            out.push(g);
    }
    return out;
}

function normalizeEffort(effort, nameById, nowMs) {
    const scored = scoreEffort(effort);
    const isPriv = isPrivateBuild(effort);
    const gta = effort.gta || {};
    const stats = effort.stats || {};
    const fps = Number(gta.fps) || 0;
    const stabKey = stabilityKey(gta.stability);
    const stabLabel = (STABILITY[stabKey] || STABILITY.unknown).label;
    const nukedObj = effort.nuked && typeof effort.nuked === "object" ? effort.nuked : null;
    const isNuked = !!nukedObj;
    const gpus = normalizeGpus(effort.gpu);

    let basedOnText = "";
    if (Array.isArray(effort.basedOn) && effort.basedOn.length > 0) {
        const names = effort.basedOn.map(id => nameById[id] || id);
        basedOnText = "Based on " + names.join(", ");
    }

    const ghUrl = safeGitHubUrl(effort.repo, effort.branch);
    const openUrl = ghUrl;
    const proofUrl = effort.proof ? safeHttpsUrl(effort.proof.url) : "";
    const breakdown = buildBreakdown(effort, scored);

    return {
        id: String(effort.id || ""),
        name: String(effort.name || effort.id || "Unknown"),
        repo: isPriv ? "" : String(effort.repo),
        branch: String(effort.branch || "main"),
        displayRepo: isPriv ? (effort.byline || "Private build") : String(effort.repo),
        isPrivate: isPriv,
        basedOnText: basedOnText,
        evidenceText: isPriv && effort.evidence ? String(effort.evidence) : "",
        tier: effort.tier === "watchlist" ? "watchlist" : "tracked",
        nuked: isNuked,
        nukedAt: nukedObj && nukedObj.at ? String(nukedObj.at) : "",
        nukedNote: nukedObj && nukedObj.note ? String(nukedObj.note) : "",
        gpus: gpus,
        gpuText: gpus.join(" / "),
        approach: String(effort.approach || ""),
        target: String(effort.target || ""),
        summary: String(effort.summary || ""),
        provenOn: effort.provenOn ? String(effort.provenOn) : "",
        verification: verificationLabel(effort.verification),
        score: scored.score,
        scoreText: formatScore(scored.score),
        reached: scored.reached,
        reachedLabel: scored.reachedLabel,
        playable: scored.playable,
        fps: fps,
        hasFps: fps > 0,
        fpsText: fps > 0 ? (Math.round(fps) + " FPS") : "—",
        fpsDetailText: fps > 0 ? (Math.round(fps) + " FPS") : (scored.playable ? "Unmeasured" : "Not playable yet"),
        stabilityLabel: stabLabel,
        pros: Array.isArray(effort.highlights) ? effort.highlights.map(String) : [],
        cons: Array.isArray(effort.blockers) ? effort.blockers.map(String) : [],
        stars: Number(stats.stars) || 0,
        starsText: isPriv ? "Private" : formatCompactCount(stats.stars),
        forksText: formatCompactCount(stats.forks),
        repoMissing: stats.missing === true,
        repoArchived: stats.archived === true,
        pushedAgo: formatAgo(stats.pushedAt, nowMs),
        openUrl: openUrl,
        isGitHubLink: ghUrl.length > 0,
        proofUrl: proofUrl,
        proofLabel: effort.proof && effort.proof.label ? String(effort.proof.label) : "Watch proof",
        breakdownKind: breakdown.kind,
        breakdownRows: breakdown.rows
    };
}

function compareEfforts(a, b) {
    if (a.nuked !== b.nuked)
        return a.nuked ? 1 : -1;
    if (b.score !== a.score)
        return b.score - a.score;
    if (b.stars !== a.stars)
        return b.stars - a.stars;
    if (b.fps !== a.fps)
        return b.fps - a.fps;
    return a.name.localeCompare(b.name);
}

function withRanks(list) {
    const out = [];
    let rank = 1;
    for (let i = 0; i < list.length; i++) {
        const item = Object.assign({}, list[i]);
        item.rank = item.nuked ? 0 : rank++;
        out.push(item);
    }
    return out;
}

function buildModel(rawData, includePrivateInTop, nowMs) {
    if (!rawData || !Array.isArray(rawData.efforts)) {
        return {
            valid: false,
            items: [],
            raceItems: [],
            allTrackedItems: [],
            watchlistItems: [],
            topPublic: null,
            topOverall: null,
            barLeader: null,
            updatedIso: "",
            updatedAgo: ""
        };
    }

    const now = Number.isFinite(nowMs) ? nowMs : Date.now();
    const nameById = {};
    for (let i = 0; i < rawData.efforts.length; i++) {
        const e = rawData.efforts[i];
        if (e && e.id)
            nameById[e.id] = e.name || e.id;
    }

    const normalized = rawData.efforts.map(e => normalizeEffort(e, nameById, now));
    normalized.sort(compareEfforts);

    const raceItems = withRanks(normalized.filter(e => e.tier === "tracked" && !e.isPrivate && !e.nuked));
    const allTrackedItems = withRanks(normalized.filter(e => e.tier === "tracked"));
    const watchlistItems = withRanks(normalized.filter(e => e.tier === "watchlist"));

    const activeTracked = allTrackedItems.filter(e => !e.nuked);
    const topPublic = raceItems.length > 0 ? raceItems[0] : null;
    const topOverall = activeTracked.length > 0 ? activeTracked[0] : null;
    const barLeader = includePrivateInTop ? (topOverall || topPublic) : (topPublic || topOverall);

    return {
        valid: true,
        items: normalized,
        raceItems: raceItems,
        allTrackedItems: allTrackedItems,
        watchlistItems: watchlistItems,
        topPublic: topPublic,
        topOverall: topOverall,
        barLeader: barLeader,
        updatedIso: String(rawData.updated || ""),
        updatedAgo: formatAgo(rawData.updated, now)
    };
}
