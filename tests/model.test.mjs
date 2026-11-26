import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const modelSource = fs
    .readFileSync(path.join(__dirname, "..", "PortWatchModel.js"), "utf8")
    .replace(/^\.pragma library\s*\n/, "");

const context = {
    Math,
    Number,
    String,
    Array,
    Object,
    Date,
    RegExp,
    encodeURIComponent
};
vm.createContext(context);
vm.runInContext(modelSource, context);

const Model = context;

// 1. Groundwork-only scoring (0-10%)
{
    const s = Model.scoreEffort({
        groundwork: { loader: 1, shaders: 0.5, graphics: 0.5, proven: 0 },
        gta: { loads: 0, boots: 0, menu: 0, world: 0, playable: 0 }
    });
    // 0.2*1 + 0.28*0.5 + 0.32*0.5 = 0.5 -> 5.0%
    assert.equal(s.score, 5.0);
    assert.equal(s.reached, "groundwork");
    assert.equal(s.playable, false);
}

// 2. Partial milestone ladder step (e.g. XCL: menu=1, world=0.5 -> 35%)
{
    const s = Model.scoreEffort({
        groundwork: { loader: 0.9, shaders: 0.9, graphics: 0.85, proven: 0.9 },
        gta: { loads: 1, boots: 1, menu: 1, world: 0.5, playable: 0 }
    });
    assert.equal(s.score, 35.0);
    assert.equal(s.reached, "menu");
}

// 3. Playable tracks (ZETTROX: story=0.1, render=0.3, fps=2, stability=0.8 -> 64.2%)
{
    const s = Model.scoreEffort({
        gta: {
            loads: 1,
            boots: 1,
            menu: 1,
            world: 1,
            playable: 1,
            story: 0.1,
            render: 0.3,
            fps: 2,
            stability: 0.8
        }
    });
    assert.equal(s.score, 64.2);
    assert.equal(s.reached, "playable");
    assert.equal(s.playable, true);
}

// 4. Full buildModel with public vs private leader, FPS, pros/cons, and nuked sorting
{
    const now = Date.parse("2026-11-25T10:00:00Z");
    const sample = {
        updated: "2026-11-25T07:00:00Z",
        efforts: [
            {
                id: "priv",
                name: "PrivateChamp",
                repo: null,
                basedOn: ["pub"],
                tier: "tracked",
                highlights: ["Private pro"],
                blockers: ["Private con"],
                gta: { loads: 1, boots: 1, menu: 1, world: 1, playable: 1, story: 0.4, render: 0.5, fps: 6, stability: 0.8 }
            },
            {
                id: "pub",
                name: "PublicLeader",
                repo: "Org/public-leader",
                tier: "tracked",
                highlights: ["Boots fast", "Renders menus"],
                blockers: ["Low FPS"],
                stats: { stars: 1250, forks: 40, pushedAt: "2026-11-25T09:00:00Z" },
                gta: { loads: 1, boots: 1, menu: 1, world: 1, playable: 1, story: 0.1, render: 0.3, fps: 2, stability: 0.8 }
            },
            {
                id: "dead",
                name: "OldPort",
                repo: "Org/old-port",
                tier: "tracked",
                nuked: { at: "2026-11-23", note: "DMCA takedown" },
                highlights: ["Ran exe"],
                blockers: ["Taken offline"],
                stats: { stars: 32000 },
                gta: { loads: 1, boots: 0, menu: 0, world: 0, playable: 0 }
            },
            {
                id: "watch",
                name: "EarlyTool",
                repo: "Org/early",
                tier: "watchlist",
                highlights: ["Clean loader"],
                blockers: ["No frames"],
                groundwork: { loader: 0.5, shaders: 0, graphics: 0, proven: 0 },
                gta: {}
            }
        ]
    };

    const publicTopModel = Model.buildModel(sample, false, now);
    assert.equal(publicTopModel.valid, true);
    assert.equal(publicTopModel.barLeader.id, "pub");
    assert.equal(publicTopModel.topOverall.id, "priv");
    assert.equal(publicTopModel.updatedAgo, "3h ago");
    assert.equal(publicTopModel.raceItems.length, 1);
    assert.equal(publicTopModel.allTrackedItems.length, 3);
    assert.equal(publicTopModel.allTrackedItems[2].id, "dead");
    assert.equal(publicTopModel.allTrackedItems[2].nuked, true);
    assert.equal(publicTopModel.watchlistItems.length, 1);

    const pub = publicTopModel.raceItems[0];
    assert.equal(pub.scoreText, "64.2%");
    assert.equal(pub.fpsText, "2 FPS");
    assert.deepEqual(pub.pros, ["Boots fast", "Renders menus"]);
    assert.deepEqual(pub.cons, ["Low FPS"]);
    assert.equal(pub.openUrl, "https://github.com/Org/public-leader");
    assert.equal(pub.stabilityLabel, "Rarely crashes");

    const privTopModel = Model.buildModel(sample, true, now);
    assert.equal(privTopModel.barLeader.id, "priv");
    assert.equal(privTopModel.barLeader.basedOnText, "Based on PublicLeader");
    assert.equal(privTopModel.barLeader.openUrl, "");
    assert.equal(privTopModel.barLeader.isGitHubLink, false);
}

// 5. Upstream portwatch verification, GPU tags, evidence, provenOn, and missing repo
{
    const now = Date.parse("2026-11-25T19:00:00Z");
    const sample = {
        updated: "2026-11-25T19:00:00Z",
        efforts: [
            {
                id: "dex",
                name: "DexNom",
                repo: "DexNom/VIctory",
                tier: "tracked",
                basedOn: ["early"],
                gpu: ["AMD", "InvalidGPU", "AMD"],
                verification: "portwatch",
                stats: { stars: 705, pushedAt: "2026-11-25T18:00:00Z" },
                gta: { loads: 1, boots: 1, menu: 1, world: 1, playable: 1, story: 0.5, render: 0.9, fps: 3, stability: 0.7 }
            },
            {
                id: "doomsday",
                name: "Doomsday",
                repo: null,
                basedOn: [],
                byline: "Working in private",
                evidence: "Confirmed by PortWatch",
                gpu: ["AMD", "NVIDIA"],
                tier: "tracked",
                verification: "portwatch",
                gta: { loads: 1, boots: 1, menu: 1, world: 1, playable: 1, story: 0.5, render: 0.85, fps: 4, stability: 0.8 }
            },
            {
                id: "early",
                name: "EarlyLayer",
                repo: "Org/early",
                tier: "watchlist",
                gpu: ["Intel"],
                provenOn: "Minecraft Preview: playable",
                stats: { stars: 10, missing: true, archived: true },
                groundwork: { loader: 0.5, shaders: 0.2, graphics: 0.2, proven: 0.5 },
                gta: {}
            }
        ]
    };

    const m = Model.buildModel(sample, false, now);
    const dex = m.raceItems[0];
    assert.equal(dex.score, 78);
    assert.equal(dex.basedOnText, "Based on EarlyLayer");
    assert.equal(dex.verification, "Verified by PortWatch");
    assert.deepEqual(Array.from(dex.gpus), ["AMD"]);
    assert.equal(dex.gpuText, "AMD");

    const priv = m.topOverall;
    assert.equal(priv.id, "doomsday");
    assert.equal(priv.basedOnText, "");
    assert.equal(priv.evidenceText, "Confirmed by PortWatch");
    assert.deepEqual(Array.from(priv.gpus), ["AMD", "NVIDIA"]);
    assert.equal(priv.gpuText, "AMD / NVIDIA");

    const early = m.watchlistItems[0];
    assert.equal(early.provenOn, "Minecraft Preview: playable");
    assert.equal(early.repoMissing, true);
    assert.equal(early.repoArchived, true);
    assert.deepEqual(Array.from(early.gpus), ["Intel"]);
}

// 6. Invalid payload rejection
{
    const bad = Model.buildModel({}, false, Date.now());
    assert.equal(bad.valid, false);
}

console.log("All PortWatchModel tests passed!");
