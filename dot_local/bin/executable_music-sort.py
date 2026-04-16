#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import zipfile

DOWNLOADS = os.path.expanduser("~/Downloads")
MUSIC = os.path.expanduser("~/Music")
AUDIO_EXTS = {".mp3", ".flac", ".m4a", ".ogg", ".opus", ".wav", ".aac", ".wma", ".ape", ".alac"}
CUTOFF = time.time() - 2 * 3600  # 2 hours ago

def sanitize(name: str) -> str:
    """Remove/replace characters invalid in directory names."""
    name = name.strip()
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '_', name)
    name = name.rstrip('. ')
    return name or "Unknown"

def get_metadata(path: str) -> dict:
    """Return {'artist': ..., 'album': ...} via ffprobe, or empty dict on failure."""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", path],
            capture_output=True, text=True, timeout=10
        )
        data = json.loads(result.stdout)
        tags = {k.lower(): v for k, v in data.get("format", {}).get("tags", {}).items()}
        artist = tags.get("artist") or tags.get("album_artist")
        album = tags.get("album")
        if artist and album:
            return {"artist": artist.strip(), "album": album.strip()}
    except Exception:
        pass
    return {}

# Common filename patterns:
#   Artist - Album - ##-## Track.ext
#   Artist - Album - ## Track.ext
#   Artist - Album - Track.ext
FILENAME_RE = re.compile(
    r'^(?P<artist>.+?)\s+-\s+(?P<album>.+?)\s+-\s+(?:\d{2}-\d{2}|\d{2,3})\s*.+$',
    re.IGNORECASE
)
FILENAME_RE_SIMPLE = re.compile(
    r'^(?P<artist>.+?)\s+-\s+(?P<album>.+?)\s+-\s+.+$',
    re.IGNORECASE
)

def parse_filename(filename: str) -> dict:
    """Try to infer artist/album from filename."""
    stem = os.path.splitext(filename)[0]
    for pattern in (FILENAME_RE, FILENAME_RE_SIMPLE):
        m = pattern.match(stem)
        if m:
            return {"artist": m.group("artist").strip(), "album": m.group("album").strip()}
    return {}

def find_recent_music() -> list[str]:
    files = []
    for entry in os.scandir(DOWNLOADS):
        if not entry.is_file():
            continue
        ext = os.path.splitext(entry.name)[1].lower()
        if ext not in AUDIO_EXTS:
            continue
        if entry.stat().st_mtime >= CUTOFF:
            files.append(entry.path)
    return sorted(files)

moved = []
skipped = []

for path in find_recent_music():
    filename = os.path.basename(path)
    info = get_metadata(path) or parse_filename(filename)

    if not info:
        skipped.append({"file": filename, "reason": "no metadata or recognizable filename pattern"})
        continue

    artist_dir = sanitize(info["artist"])
    album_dir = sanitize(info["album"])
    dest_dir = os.path.join(MUSIC, artist_dir, album_dir)
    os.makedirs(dest_dir, exist_ok=True)

    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        skipped.append({"file": filename, "reason": f"already exists at {dest}"})
        continue

    shutil.move(path, dest)
    moved.append({
        "file": filename,
        "source": "metadata" if get_metadata(path) == {} else "metadata/filename",
        "dest": os.path.join(artist_dir, album_dir),
    })

# --- Phase 2: Extract zips in ~/Music, categorize contents, delete zips ---
extracted = []
extract_skipped = []
deleted_zips = []

def find_zips_in_music() -> list[str]:
    zips = []
    for root, _dirs, files in os.walk(MUSIC):
        for f in files:
            if f.lower().endswith(".zip"):
                zips.append(os.path.join(root, f))
    return sorted(zips)

for zip_path in find_zips_in_music():
    zip_name = os.path.basename(zip_path)
    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            with tempfile.TemporaryDirectory() as tmpdir:
                zf.extractall(tmpdir)
                found_audio = False
                for root, _dirs, files in os.walk(tmpdir):
                    for fname in files:
                        ext = os.path.splitext(fname)[1].lower()
                        if ext not in AUDIO_EXTS:
                            continue
                        found_audio = True
                        fpath = os.path.join(root, fname)
                        info = get_metadata(fpath) or parse_filename(fname)
                        if not info:
                            extract_skipped.append({"file": fname, "zip": zip_name, "reason": "no metadata or recognizable filename"})
                            continue
                        artist_dir = sanitize(info["artist"])
                        album_dir = sanitize(info["album"])
                        dest_dir = os.path.join(MUSIC, artist_dir, album_dir)
                        os.makedirs(dest_dir, exist_ok=True)
                        dest = os.path.join(dest_dir, fname)
                        if os.path.exists(dest):
                            extract_skipped.append({"file": fname, "zip": zip_name, "reason": f"already exists at {dest}"})
                            continue
                        shutil.move(fpath, dest)
                        extracted.append({"file": fname, "zip": zip_name, "dest": os.path.join(artist_dir, album_dir)})
                if not found_audio:
                    extract_skipped.append({"file": zip_name, "zip": zip_name, "reason": "no audio files found in zip"})
                    continue
        os.remove(zip_path)
        deleted_zips.append(zip_name)
    except zipfile.BadZipFile:
        extract_skipped.append({"file": zip_name, "zip": zip_name, "reason": "not a valid zip file"})
    except Exception as e:
        extract_skipped.append({"file": zip_name, "zip": zip_name, "reason": str(e)})

# Output report
print(f"\n=== Music Sort Report ===")
print(f"Moved from Downloads: {len(moved)} file(s)")
print(f"Extracted from zips:  {len(extracted)} file(s)")
print(f"Zips deleted:         {len(deleted_zips)}")
print(f"Skipped:              {len(skipped) + len(extract_skipped)} file(s)")

if moved:
    print("\nMoved from Downloads:")
    by_dest = {}
    for m in moved:
        by_dest.setdefault(m["dest"], []).append(m["file"])
    for dest, files in sorted(by_dest.items()):
        print(f"  {dest}/")
        for f in files:
            print(f"    {f}")

if extracted:
    print("\nExtracted from zips:")
    by_dest = {}
    for m in extracted:
        by_dest.setdefault(m["dest"], []).append(f"{m['file']} (from {m['zip']})")
    for dest, files in sorted(by_dest.items()):
        print(f"  {dest}/")
        for f in files:
            print(f"    {f}")

if deleted_zips:
    print("\nDeleted zips:")
    for z in deleted_zips:
        print(f"  {z}")

all_skipped = skipped + extract_skipped
if all_skipped:
    print("\nSkipped:")
    for s in all_skipped:
        print(f"  {s['file']}: {s['reason']}")
