@if (@X)==(@Y) @end /*
@echo off
cscript //nologo //E:jscript "%~f0" %*
exit /b %errorlevel%
*/

// ================================================================
//  colpress-dupe.bat  v2.0  —  Duplicate File Finder
//  Part of Colpress v2.0. Batch/JScript polyglot. No install.
//
//  Hash engine priority (fastest to slowest):
//    1. b3sum.exe  BLAKE3   (tools\b3sum.exe) — ~3x faster than SHA-256
//    2. certutil   SHA-256  (Windows 7+)       — 20-100x faster than FNV
//    3. JScript    FNV-1a   (XP fallback)      — always available
//
//  3-phase duplicate detection:
//    Phase 1 — Group by exact size     (zero I/O)
//    Phase 2 — Head hash first 64 KB   (JScript FNV, avoids spawn overhead)
//    Phase 3 — Full hash               (best engine, only real candidates)
//
//  Small-file optimisation (NEW v2.0):
//    Files <=64 KB are fully read in Phase 2. Phase 3 reuses that hash,
//    eliminating a second disk read for every small duplicate candidate.
//
//  Changes vs dupefind.bat v1.2:
//    NEW  b3sum BLAKE3 engine for Phase 3 (primary, ~3x faster than SHA-256)
//    NEW  /virus flag — SHA-256 + VirusTotal URL per unique duplicate group
//    NEW  HTML export — auto-detected when /export: path ends in .html
//    NEW  Small-file optimisation — no re-read for files <= 64 KB
//    NEW  Colpress v2.0 branding
//
//  Usage:
//    colpress-dupe.bat <directory>
//    colpress-dupe.bat <directory> /min:<bytes>
//    colpress-dupe.bat <directory> /export:<file.csv>
//    colpress-dupe.bat <directory> /export:<file.html>
//    colpress-dupe.bat <directory> /delete
//    colpress-dupe.bat <directory> /virus
//    colpress-dupe.bat /?
// ================================================================

"use strict";

var stdout = WScript.StdOut;
var stderr = WScript.StdErr;
var fso    = new ActiveXObject("Scripting.FileSystemObject");

var VERSION    = "2.0";
var HEAD_BYTES = 65536;   // 64 KB — Phase 2 read window
var CHUNK_SIZE = 4194304; // 4 MB  — streaming chunk for JScript FNV
var FNV_PRIME  = 0x01000193;
var FNV_SEED1  = 0x811c9dc5;
var FNV_SEED2  = 0x84222325;
var REPARSE    = 0x400;   // FILE_ATTRIBUTE_REPARSE_POINT — skip symlinks

// ── Tool paths ───────────────────────────────────────────────────
var SCRIPT_DIR = (function() {
    try {
        var p = WScript.ScriptFullName;
        return p.substring(0, p.lastIndexOf("\\"));
    } catch(e) { return "."; }
})();

var B3SUM_PATH = (function() {
    try {
        var p = SCRIPT_DIR + "\\tools\\b3sum.exe";
        return fso.FileExists(p) ? p : null;
    } catch(e) { return null; }
})();

var CERTUTIL_PATH = (function() {
    try {
        var wsh  = new ActiveXObject("WScript.Shell");
        var sys  = wsh.ExpandEnvironmentStrings("%SystemRoot%\\System32");
        var p    = sys + "\\certutil.exe";
        return fso.FileExists(p) ? p : null;
    } catch(e) { return null; }
})();

// ── Argument parsing ─────────────────────────────────────────────
var scanPath   = "";
var minSize    = 1;
var exportPath = "";
var doDelete   = false;
var doVirus    = false;

(function() {
    var args = WScript.Arguments;
    for (var i = 0; i < args.length; i++) {
        var a  = args(i);
        var lo = a.toLowerCase();
        if (lo === "/?" || lo === "-?" || lo === "/help") { showHelp(); WScript.Quit(0); }
        else if (lo.indexOf("/min:")    === 0 || lo.indexOf("-min:")    === 0) { minSize    = parseInt(a.slice(5), 10) || 1; }
        else if (lo.indexOf("/export:") === 0 || lo.indexOf("-export:") === 0) { exportPath = a.slice(8); }
        else if (lo === "/delete" || lo === "-delete") { doDelete = true; }
        else if (lo === "/virus"  || lo === "-virus")  { doVirus  = true; }
        else if (a.charAt(0) !== "/" && a.charAt(0) !== "-" && scanPath === "") { scanPath = a; }
    }
})();

if (scanPath === "") {
    stderr.WriteLine("ERROR: No directory specified. Run colpress-dupe.bat /? for help.");
    WScript.Quit(1);
}
try {
    scanPath = fso.GetFolder(scanPath).Path;
} catch(e) {
    stderr.WriteLine("ERROR: Cannot access directory: " + scanPath);
    WScript.Quit(1);
}

// ── Utilities ────────────────────────────────────────────────────
function fmtSize(b) {
    if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB";
    if (b >= 1048576)    return (b / 1048576).toFixed(2)    + " MB";
    if (b >= 1024)       return (b / 1024).toFixed(2)       + " KB";
    return b + " B";
}
function repeat(c, n) { var s = ""; while (s.length < n) s += c; return s; }
function rpad(s, w)   { s = "" + s; return s   + repeat(" ", Math.max(0, w - s.length)); }
function lpad(s, w)   { s = "" + s; return repeat(" ", Math.max(0, w - s.length)) + s; }
function println(s)   { stdout.WriteLine(s || ""); }
function fmtDate(d) {
    try {
        d = new Date(d);
        return d.getFullYear() + "-" +
               ("0" + (d.getMonth() + 1)).slice(-2) + "-" +
               ("0" + d.getDate()).slice(-2) + " " +
               ("0" + d.getHours()).slice(-2) + ":" +
               ("0" + d.getMinutes()).slice(-2);
    } catch(e) { return "????-??-?? ??:??"; }
}

// ── JScript dual-FNV-1a ──────────────────────────────────────────
function fnvMul(h) {
    var lo = h & 0xffff, hi = h >>> 16;
    return (((lo * FNV_PRIME) >>> 0) + (((hi * FNV_PRIME) & 0xffff) << 16)) >>> 0;
}
function hashSlice(arr, start, end, h1, h2, pos) {
    pos = pos | 0;
    for (var i = start; i < end; i++) {
        var b = arr[i];
        h1 = fnvMul((h1 ^ b) >>> 0);
        h2 = fnvMul((h2 ^ (b ^ (pos & 0xff))) >>> 0);
        pos = (pos + 1) | 0;
    }
    return { h1: h1, h2: h2, pos: pos };
}
function toHex(h1, h2) {
    return ("00000000" + (h1 >>> 0).toString(16)).slice(-8) +
           ("00000000" + (h2 >>> 0).toString(16)).slice(-8);
}
function openStream(path) {
    try {
        var s = new ActiveXObject("ADODB.Stream");
        s.Type = 1; s.Open(); s.LoadFromFile(path);
        return s;
    } catch(e) { return null; }
}
function readChunk(stream, n) {
    try {
        if (stream.EOS) return null;
        var raw = stream.Read(n);
        return (raw === null || typeof raw === "undefined") ? null : new VBArray(raw).toArray();
    } catch(e) { return null; }
}

// Phase 2: head hash (64 KB via JScript — avoids process spawn overhead)
function headHash(path) {
    var s = openStream(path);
    if (!s) return null;
    var arr = readChunk(s, HEAD_BYTES);
    try { s.Close(); } catch(e) {}
    if (!arr || arr.length === 0) return null;
    var r = hashSlice(arr, 0, arr.length, FNV_SEED1, FNV_SEED2, 0);
    return toHex(r.h1, r.h2);
}

// Phase 3 JScript fallback: full FNV stream hash (XP-compatible)
function fullHashFNV(path) {
    var s = openStream(path);
    if (!s) return null;
    var h1 = FNV_SEED1, h2 = FNV_SEED2, pos = 0;
    while (!s.EOS) {
        var arr = readChunk(s, CHUNK_SIZE);
        if (!arr) break;
        var r = hashSlice(arr, 0, arr.length, h1, h2, pos);
        h1 = r.h1; h2 = r.h2; pos = r.pos;
    }
    try { s.Close(); } catch(e) {}
    return toHex(h1, h2);
}

// Phase 3: b3sum BLAKE3 (primary — fastest)
function b3sumHash(path) {
    if (!B3SUM_PATH) return null;
    try {
        var wsh    = new ActiveXObject("WScript.Shell");
        var safeP  = path.replace(/"/g, "");
        var exec   = wsh.Exec('"' + B3SUM_PATH + '" "' + safeP + '"');
        var out    = exec.StdOut.ReadAll();
        var m      = out.match(/^([0-9a-f]{64})/);
        return m ? m[1] : null;
    } catch(e) { return null; }
}

// Phase 3: certutil SHA-256 (secondary)
function certutilHash(path) {
    if (!CERTUTIL_PATH) return null;
    try {
        var wsh   = new ActiveXObject("WScript.Shell");
        var safeP = path.replace(/"/g, "");
        var exec  = wsh.Exec('%COMSPEC% /c "' + CERTUTIL_PATH +
                              '" -hashfile "' + safeP + '" SHA256 2>nul');
        var out   = exec.StdOut.ReadAll();
        var lines = out.split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
            var h = lines[i].replace(/[ \t]/g, "").toLowerCase();
            if (/^[0-9a-f]{64}$/.test(h)) return h;
        }
        return null;
    } catch(e) { return null; }
}

// Unified Phase 3 dispatcher
function fullHashBest(path) {
    if (B3SUM_PATH)    return b3sumHash(path);
    if (CERTUTIL_PATH) return certutilHash(path);
    return fullHashFNV(path);
}

// SHA-256 for VirusTotal (VT requires SHA-256 regardless of Phase 3 engine)
function vtSHA256(path) { return certutilHash(path); }

// ── File enumeration ─────────────────────────────────────────────
// O(1) dequeue via index pointer (vs O(n) queue.shift() in v1.1)
function enumFiles(root, minSz) {
    var files = [], queue = [root], qi = 0;
    while (qi < queue.length) {
        var dirPath = queue[qi++];
        try {
            var dir = fso.GetFolder(dirPath);
            var fe  = new Enumerator(dir.Files);
            for (; !fe.atEnd(); fe.moveNext()) {
                var f = fe.item();
                try {
                    if (f.Size >= minSz)
                        files.push({ path: f.Path, size: f.Size, modified: fmtDate(f.DateLastModified), headHash: null });
                } catch(e) {}
            }
            var de = new Enumerator(dir.SubFolders);
            for (; !de.atEnd(); de.moveNext()) {
                var sub = de.item();
                try { if (!(sub.Attributes & REPARSE)) queue.push(sub.Path); } catch(e) {}
            }
        } catch(e) {}
    }
    return files;
}

// ── Grouping ──────────────────────────────────────────────────────
function filterCandidates(files, keyFn) {
    var groups = {}, candidates = [], skipped = 0;
    for (var i = 0; i < files.length; i++) {
        var k = keyFn(files[i]);
        if (k === null) continue;
        if (!groups[k]) groups[k] = [];
        groups[k].push(files[i]);
    }
    for (var key in groups) {
        if (groups[key].length >= 2) {
            for (var j = 0; j < groups[key].length; j++) candidates.push(groups[key][j]);
        } else { skipped++; }
    }
    return { candidates: candidates, skipped: skipped };
}

// ── Progress bar ─────────────────────────────────────────────────
function progress(label, done, total) {
    var pct    = total > 0 ? Math.round(done / total * 100) : 100;
    var filled = Math.round(pct / 5);
    stdout.Write("\r  " + label + " [" + repeat("#", filled) + repeat(".", 20 - filled) + "] " +
                 lpad(pct, 3) + "% (" + done + "/" + total + ")   ");
}
function clearProgress() { stdout.Write("\r" + repeat(" ", 78) + "\r"); }

// ── Hash engine label ─────────────────────────────────────────────
var hashEngine = B3SUM_PATH    ? "b3sum BLAKE3 (primary — fastest)" :
                 CERTUTIL_PATH ? "certutil SHA-256 (native)" :
                                 "JScript dual-FNV-1a (XP fallback)";

// ── Banner ────────────────────────────────────────────────────────
println();
println("  " + repeat("=", 66));
println("   COLPRESS DUPEFIND v" + VERSION + "  —  Duplicate File Finder");
println("  " + repeat("=", 66));
println("  Scan root   : " + scanPath);
println("  Min. size   : " + fmtSize(minSize));
println("  Hash engine : " + hashEngine);
println("  Phases      : size group -> head hash (64 KB) -> full hash");
if (doVirus) println("  /virus      : SHA-256 + VirusTotal links will be shown");
println("  " + repeat("-", 66));

var t0 = new Date().getTime();

// ── Phase 1: Enumerate ────────────────────────────────────────────
println();
println("  [1/3] Enumerating files...");
var allFiles = enumFiles(scanPath, minSize);
println("        Found " + allFiles.length + " file(s) >= " + fmtSize(minSize));

if (allFiles.length < 2) {
    println();
    println("  No duplicates possible with fewer than 2 files.");
    println("  Done in " + ((new Date().getTime() - t0) / 1000).toFixed(2) + " s");
    println();
    WScript.Quit(0);
}

// ── Phase 2: Size group then head hash (64 KB) ────────────────────
println();
println("  [2/3] Head hashing candidates (first 64 KB)...");

var phase1       = filterCandidates(allFiles, function(f) { return "" + f.size; });
var sizeSkipped  = allFiles.length - phase1.candidates.length;
var sizeCands    = phase1.candidates;

println("        Unique size (skipped)  : " + sizeSkipped);
println("        Size-duplicate files   : " + sizeCands.length);

if (sizeCands.length < 2) {
    println(); println("  No duplicates found.");
    println("  Done in " + ((new Date().getTime() - t0) / 1000).toFixed(2) + " s");
    println(); WScript.Quit(0);
}

var hhi    = 0;
var phase2 = filterCandidates(sizeCands, function(f) {
    hhi++;
    progress("Head hash", hhi, sizeCands.length);
    var h    = headHash(f.path);
    f.headHash = h; // cache for small-file optimisation in Phase 3
    return h ? f.size + "|" + h : null;
});
clearProgress();

var headCands = phase2.candidates;
println("        Head-hash unique (skipped) : " + phase2.skipped);
println("        Remaining candidates       : " + headCands.length);

if (headCands.length < 2) {
    println(); println("  No duplicates found.");
    println("  Done in " + ((new Date().getTime() - t0) / 1000).toFixed(2) + " s");
    println(); WScript.Quit(0);
}

// ── Phase 3: Full hash ────────────────────────────────────────────
println();
println("  [3/3] Full hashing remaining candidates...");

var finalGroups = {};
for (var i = 0; i < headCands.length; i++) {
    var f = headCands[i];
    progress("Full hash ", i + 1, headCands.length);

    var h;
    // Small-file optimisation: head hash already read the full file
    if (f.size <= HEAD_BYTES && f.headHash) {
        h = "fnv:" + f.headHash; // consistent prefix; no re-read
    } else {
        h = fullHashBest(f.path);
    }
    if (h === null) continue;

    var key = f.size + "|" + h;
    if (!finalGroups[key]) finalGroups[key] = [];
    finalGroups[key].push(f);
}
clearProgress();

var p3skipped = 0;
for (var key in finalGroups) { if (finalGroups[key].length < 2) p3skipped++; }

var dupeGroups = [];
for (var key in finalGroups) {
    if (finalGroups[key].length >= 2) {
        var grp = finalGroups[key];
        grp.sort(function(a, b) { return a.modified < b.modified ? -1 : a.modified > b.modified ? 1 : 0; });
        dupeGroups.push(grp);
    }
}
dupeGroups.sort(function(a, b) { return b[0].size * (b.length - 1) - a[0].size * (a.length - 1); });

var elapsed = ((new Date().getTime() - t0) / 1000).toFixed(2);

println("        Full-hash unique (skipped) : " + p3skipped);
println("        Confirmed duplicate groups : " + dupeGroups.length);

if (dupeGroups.length === 0) {
    println(); println("  No duplicates found.");
    println("  Done in " + elapsed + " s  |  Scanned " + allFiles.length + " file(s)");
    println(); WScript.Quit(0);
}

var totalWasted = 0;
for (var gi = 0; gi < dupeGroups.length; gi++)
    totalWasted += dupeGroups[gi][0].size * (dupeGroups[gi].length - 1);

// ── Results ───────────────────────────────────────────────────────
println();
println("  " + repeat("=", 66));
println("  RESULTS  —  sorted by wasted space (largest first)");
println("  " + repeat("=", 66));

for (var gi = 0; gi < dupeGroups.length; gi++) {
    var g      = dupeGroups[gi];
    var sz     = g[0].size;
    var wasted = sz * (g.length - 1);
    println();
    println("  Group " + (gi + 1) + "  |  " + g.length + " copies  |  " +
            fmtSize(sz) + " each  |  wasted: " + fmtSize(wasted));
    println("  " + repeat("-", 64));
    for (var fi = 0; fi < g.length; fi++) {
        var mark = (fi === 0) ? " [KEEP?]" : "        ";
        println("  " + lpad(fi + 1, 2) + "." + mark + "  " + g[fi].modified + "  " + g[fi].path);
    }
}

println();
println("  " + repeat("=", 66));
println("  SUMMARY");
println("  " + repeat("=", 66));
println("  Duplicate groups  : " + dupeGroups.length);
println("  Reclaimable space : " + fmtSize(totalWasted));
println("  Files scanned     : " + allFiles.length);
println("  Time elapsed      : " + elapsed + " s");
println("  Hash engine       : " + hashEngine);
println("  " + repeat("=", 66));

// ── CSV export ────────────────────────────────────────────────────
var exportHTML = exportPath.toLowerCase().slice(-5) === ".html";

if (exportPath !== "" && !exportHTML) {
    try {
        var csv = fso.CreateTextFile(exportPath, true, true);
        csv.WriteLine("GroupID,FilePath,SizeBytes,SizeHuman,LastModified,WastedBytes,Recommended");
        for (var gi = 0; gi < dupeGroups.length; gi++) {
            var g = dupeGroups[gi], sz = g[0].size, w = sz * (g.length - 1);
            for (var fi = 0; fi < g.length; fi++) {
                var rec = (fi === 0) ? "KEEP" : "REVIEW";
                var p   = '"' + g[fi].path.replace(/"/g, '""') + '"';
                csv.WriteLine((gi+1) + "," + p + "," + sz + "," + fmtSize(sz) + "," +
                              g[fi].modified + "," + w + "," + rec);
            }
        }
        csv.Close();
        println(); println("  CSV exported to: " + exportPath);
    } catch(e) { stderr.WriteLine("  ERROR writing CSV: " + e.message); }
}

// ── HTML export ───────────────────────────────────────────────────
if (exportPath !== "" && exportHTML) {
    try {
        var hf = fso.CreateTextFile(exportPath, true, true);
        hf.WriteLine("<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'>");
        hf.WriteLine("<title>Colpress Dupe Report</title>");
        hf.WriteLine("<style>body{font-family:Consolas,monospace;background:#111;color:#ddd;padding:24px;margin:0}");
        hf.WriteLine("h2{color:#4af}h3{color:#fa0;margin:20px 0 4px}table{border-collapse:collapse;width:100%;margin-bottom:12px}");
        hf.WriteLine("th,td{padding:6px 12px;border-bottom:1px solid #2a2a2a;text-align:left;word-break:break-all}");
        hf.WriteLine("th{background:#1a1a1a;color:#aaa}.keep{color:#4f4}a{color:#4af;text-decoration:none}a:hover{text-decoration:underline}</style></head><body>");
        hf.WriteLine("<h2>Colpress v2.0 — Duplicate File Report</h2>");
        hf.WriteLine("<p>Directory: " + scanPath + " | Groups: " + dupeGroups.length +
                     " | Reclaimable: " + fmtSize(totalWasted) + " | Engine: " + hashEngine + "</p>");
        for (var gi = 0; gi < dupeGroups.length; gi++) {
            var g = dupeGroups[gi], sz = g[0].size, w = sz * (g.length - 1);
            hf.WriteLine("<h3>Group " + (gi+1) + " — " + g.length + " copies | " +
                         fmtSize(sz) + " each | wasted: " + fmtSize(w) + "</h3>");
            hf.WriteLine("<table><tr><th>#</th><th>Recommendation</th><th>Modified</th><th>Path</th><th>VT Check</th></tr>");
            for (var fi = 0; fi < g.length; fi++) {
                var rec = (fi === 0) ? "<span class='keep'>KEEP?</span>" : "REVIEW";
                // VT link uses SHA-256 — we show it as a link placeholder;
                // actual SHA-256 column only computed with /virus flag
                hf.WriteLine("<tr><td>" + (fi+1) + "</td><td>" + rec + "</td><td>" +
                             g[fi].modified + "</td><td>" + g[fi].path + "</td>" +
                             "<td><a href='https://www.virustotal.com/gui/home/search' target='_blank'>Search VT</a></td></tr>");
            }
            hf.WriteLine("</table>");
        }
        hf.WriteLine("</body></html>");
        hf.Close();
        println(); println("  HTML exported to: " + exportPath);
    } catch(e) { stderr.WriteLine("  ERROR writing HTML: " + e.message); }
}

// ── VirusTotal links (/virus flag) ────────────────────────────────
if (doVirus) {
    println();
    println("  " + repeat("=", 66));
    println("  VIRUS SCAN MODE  —  VirusTotal Links (SHA-256)");
    println("  " + repeat("=", 66));
    if (!CERTUTIL_PATH) {
        println("  [WARN] certutil not found. SHA-256 unavailable (requires Windows 7+).");
        println("         Cannot generate VirusTotal links.");
    } else {
        println("  Computing SHA-256 for one file per duplicate group...");
        println("  (VT direct link opens the exact result page — no copy/paste needed)");
        println();
        var vtSeenHashes = {};
        for (var gi = 0; gi < dupeGroups.length; gi++) {
            var g    = dupeGroups[gi];
            var keep = g[0]; // oldest = keep candidate
            var sha  = vtSHA256(keep.path);
            if (!sha) {
                println("  Group " + (gi+1) + ": [could not compute SHA-256 — file may be locked]");
                println();
                continue;
            }
            if (vtSeenHashes[sha]) {
                println("  Group " + (gi+1) + ": (same hash as earlier group — skipped)");
                continue;
            }
            vtSeenHashes[sha] = true;
            var vtURL = "https://www.virustotal.com/gui/file/" + sha;
            println("  Group " + (gi+1) + ":");
            println("    File    : " + keep.path);
            println("    SHA-256 : " + sha);
            println("    VT URL  : " + vtURL);
            println();
        }
        stdout.Write("  Open all VT links in browser now? (Y/N): ");
        var ans = "";
        try { ans = WScript.StdIn.ReadLine().trim(); } catch(e) {}
        if (ans.toLowerCase() === "y") {
            var wsh3 = new ActiveXObject("WScript.Shell");
            for (var sha in vtSeenHashes)
                wsh3.Run('cmd /c start "" "https://www.virustotal.com/gui/file/' + sha + '"');
        }
    }
    println("  " + repeat("=", 66));
}

// ── Interactive delete ────────────────────────────────────────────
if (doDelete) {
    println();
    println("  " + repeat("=", 66));
    println("  INTERACTIVE DELETE MODE");
    println("  " + repeat("=", 66));
    println("  For each group, type number(s) to DELETE (comma-separated).");
    println("  Press ENTER to skip a group. [KEEP?] = oldest file in group.");
    println("  WARNING: Files deleted here may NOT go to the Recycle Bin.");
    println("           Use colpress-wipe or sdelete64 for secure erasure.");
    println("  " + repeat("=", 66));

    for (var gi = 0; gi < dupeGroups.length; gi++) {
        var g = dupeGroups[gi], sz = g[0].size;
        println();
        println("  --- Group " + (gi+1) + "/" + dupeGroups.length +
                "  (" + g.length + " copies, " + fmtSize(sz) + " each) ---");
        for (var fi = 0; fi < g.length; fi++) {
            var mark = (fi === 0) ? " [KEEP?]" : "        ";
            println("  " + lpad(fi + 1, 2) + "." + mark + "  " + g[fi].modified + "  " + g[fi].path);
        }
        stdout.Write("  Delete which? (e.g. 2,3 or ENTER to skip): ");
        var input = "";
        try { input = WScript.StdIn.ReadLine().trim(); } catch(e) {}
        if (input === "") { println("  Skipped."); continue; }
        var parts = input.split(",");
        for (var pi = 0; pi < parts.length; pi++) {
            var idx = parseInt(parts[pi].trim(), 10);
            if (isNaN(idx) || idx < 1 || idx > g.length) {
                println("  ! Invalid index " + parts[pi].trim() + " — skipped.");
                continue;
            }
            var target = g[idx - 1].path;
            try { fso.DeleteFile(target, true); println("  Deleted: " + target); }
            catch(e) { println("  FAILED:  " + target + "  (" + e.message + ")"); }
        }
    }
    println();
    println("  Delete session complete.");
}

println();

// ── Help ──────────────────────────────────────────────────────────
function showHelp() {
    println();
    println("  COLPRESS DUPEFIND v" + VERSION + "  —  Duplicate File Finder");
    println("  Batch/JScript polyglot. Windows XP+ (b3sum speedup if tools\\b3sum.exe present).");
    println();
    println("  USAGE:");
    println("    colpress-dupe.bat <directory> [options]");
    println();
    println("  OPTIONS:");
    println("    /min:<bytes>        Skip files smaller than <bytes>");
    println("                        e.g. /min:102400  (ignore files under 100 KB)");
    println("    /export:<path.csv>  Write results to a CSV file");
    println("    /export:<path.html> Write results to an HTML file (clickable VT links)");
    println("    /delete             Interactive deletion mode after scan");
    println("    /virus              Compute SHA-256 + VirusTotal URL per unique group");
    println("    /?                  Show this help");
    println();
    println("  HASH ENGINE PRIORITY:");
    println("    b3sum BLAKE3    : tools\\b3sum.exe present — primary, fastest (~3x SHA-256)");
    println("    certutil SHA-256: Windows 7+ built-in — secondary, 20-100x faster than FNV");
    println("    JScript FNV-1a  : XP fallback — no dependencies");
    println();
    println("  SMALL-FILE OPTIMISATION (v2.0):");
    println("    Files <=64 KB are fully read in Phase 2 (head hash).");
    println("    Phase 3 reuses that result — no second disk read.");
    println();
    println("  EXAMPLES:");
    println("    colpress-dupe.bat D:\\Photos");
    println("    colpress-dupe.bat D:\\ /min:1048576 /export:C:\\dupes.csv");
    println("    colpress-dupe.bat D:\\ /export:C:\\dupes.html");
    println("    colpress-dupe.bat C:\\Downloads /delete");
    println("    colpress-dupe.bat C:\\Downloads /virus");
    println();
}
