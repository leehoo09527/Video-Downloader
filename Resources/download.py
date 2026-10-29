import os
import sys
from pathlib import Path

# Give the app one process group to stop both downloader and merge subprocesses.
try:
    os.setsid()
except OSError:
    pass

from yt_dlp import main

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Missing destination or URL')
    destination, url = sys.argv[1:]
    Path(destination).mkdir(parents=True, exist_ok=True)
    main([
        '--ignore-config', '--no-playlist', '--impersonate', 'chrome',
        '--newline', '--progress-delta', '1', '--no-colors',
        '--socket-timeout', '30', '--retries', '3', '--fragment-retries', '3',
        '--ffmpeg-location', '/opt/homebrew/bin',
        '--merge-output-format', 'mp4/mkv',
        '-P', destination, '-o', '%(title).150B [%(id)s].%(ext)s',
        '--', url,
    ])
