from __future__ import unicode_literals
import youtube_dl
import multiprocessing

def ydlTarget(_url, _opt):
    try:
        with youtube_dl.YoutubeDL(_opt) as ydl:
            ydl.download([_url])
    except Exception as e:
        print(f"failed to get {_url} because:\n-----Start Error-----\n{e}\n-----End Error-----\n")


if __name__ == "__main__":
    ydl_opts = {
        'format': 'best',
        'cachedir': False,
        'force_generic_extractor': False, #true if not youtube or other directly supported site
        'quiet': True,
        'no_warnings': True,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }]
    }
    targets = [
        "https://www.youtube.com/watch?v=aCyGvGEtOwc",
        "https://www.youtube.com/watch?v=AEB6ibtdPZc",
        "https://www.youtube.com/watch?v=EFEmTsfFL5A",
        "https://www.youtube.com/watch?v=OblL026SvD4"
    ]

    for target in targets:
        proc = multiprocessing.Process(target=ydlTarget, args=(target, ydl_opts))
        proc.start()
