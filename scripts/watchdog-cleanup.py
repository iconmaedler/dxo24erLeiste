#!/usr/bin/env python3
import os, time

MAX_AGE_SECONDS = 3600  # 1 hour
DIRECTORIES = [
    (".build", "macOS build artifacts"),
    ("DerivedData", "Xcode derived data"),
    (".tmp", "temporary files"),
]

removed = []

for directory, description in DIRECTORIES:
    if not os.path.isdir(directory):
        continue
    for root, dirs, files in os.walk(directory):
        for f in files:
            fp = os.path.join(root, f)
            try:
                age = time.time() - os.path.getmtime(fp)
            except OSError:
                continue
            if age > MAX_AGE_SECONDS:
                try:
                    os.remove(fp)
                    removed.append(fp)
                except OSError:
                    pass

print(f"Removed {len(removed)} files from watchdog cleanup.")
