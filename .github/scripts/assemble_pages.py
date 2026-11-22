"""Arrange the files that GitHub Pages serves.

    python3 .github/scripts/assemble_pages.py OUT_DIR

Copies the interactive site and the HTML and PDF copies of the documents into OUT_DIR, in the same
places as in the repository, so that the links between them work unchanged:

    OUT_DIR/index.html            sends the visitor on to site/
    OUT_DIR/site/index.html       the interactive site
    OUT_DIR/docs/*.html, *.pdf    the documents

Nothing is built here: the files are taken as committed. Links from the documents to files that are
not served (code, tables, logs, Markdown sources) are pointed at the same file in the repository on
GitHub. The repository's name (owner/name) and branch come from the GITHUB_REPOSITORY and
GITHUB_REF_NAME variables that GitHub Actions sets.
"""
import glob
import os
import re
import shutil
import sys

if len(sys.argv) != 2:
    sys.exit(__doc__)
out = sys.argv[1]
repo = os.environ.get("GITHUB_REPOSITORY", "")
if not re.fullmatch(r"[\w.-]+/[\w.-]+", repo):
    sys.exit("GITHUB_REPOSITORY must be set to owner/name")
branch = os.environ.get("GITHUB_REF_NAME") or "main"
blob = "https://github.com/%s/blob/%s/" % (repo, branch)

os.makedirs(os.path.join(out, "site"), exist_ok=True)
os.makedirs(os.path.join(out, "docs"), exist_ok=True)
shutil.copyfile("site/index.html", os.path.join(out, "site", "index.html"))
served = set()
for f in sorted(glob.glob("docs/*.html") + glob.glob("docs/*.pdf")):
    name = os.path.basename(f)
    shutil.copyfile(f, os.path.join(out, "docs", name))
    served.add(name)
if not served:
    sys.exit("No documents found in docs/")

changed = 0


def fix(m):
    """One href: left alone if it is absolute, on the same page, or served here; else sent to the repository."""
    global changed
    href = m.group(1)
    if re.match(r"(?:[a-z][a-z0-9+.-]*:|#|//)", href, re.I):
        return m.group(0)
    path, _, frag = href.partition("#")
    if path.startswith("../site/") or path in served:
        return m.group(0)
    target = path[3:] if path.startswith("../") else "docs/" + path
    changed += 1
    return 'href="%s%s%s"' % (blob, target, "#" + frag if frag else "")


for f in sorted(glob.glob(os.path.join(out, "docs", "*.html"))):
    with open(f, encoding="utf-8") as fh:
        text = fh.read()
    with open(f, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(re.sub(r'href="([^"]*)"', fix, text))

with open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write("""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Texas COVID-19 Vaccination Coverage</title>
<meta http-equiv="refresh" content="0; url=site/">
</head><body>
<p><a href="site/">Texas COVID-19 vaccination coverage: the interactive report</a></p>
</body></html>
""")

total = 0
for root, _, files in os.walk(out):
    for name in sorted(files):
        p = os.path.join(root, name)
        total += os.path.getsize(p)
        print("%9.1f KB  %s" % (os.path.getsize(p) / 1024, os.path.relpath(p, out).replace(os.sep, "/")))
print("%d links now point at %s; %.1f MB in all" % (changed, blob, total / 1e6))
