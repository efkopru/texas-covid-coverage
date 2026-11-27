"""Arrange the files that GitHub Pages serves.

    python3 .github/scripts/assemble_pages.py OUT_DIR

Copies the interactive site and the HTML and PDF copies of the documents into OUT_DIR, in the same
places as in the repository, so that the links between them work unchanged:

    OUT_DIR/index.html            sends the visitor on to site/
    OUT_DIR/site/index.html       the interactive site
    OUT_DIR/site/preview.png      the picture that link previews show
    OUT_DIR/docs/*.html, *.pdf    the documents

Nothing is built here: the files are taken as committed. Links from the documents to files that are
not served (code, tables, logs, Markdown sources) are pointed at the same file in the repository on
GitHub. The repository's name (owner/name) and branch come from the GITHUB_REPOSITORY and
GITHUB_REF_NAME variables that GitHub Actions sets.

Every page also gets the tags that link previews read (Open Graph and Twitter), built from its own
title and description and from the site's web address. That address comes from PAGES_BASE_URL, which
the workflow takes from actions/configure-pages; without it, the usual github.io address is assumed.
"""
import glob
import html
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
if not os.path.exists("site/preview.png"):
    sys.exit("site/preview.png is missing: R/16_build_site.R makes it")
shutil.copyfile("site/preview.png", os.path.join(out, "site", "preview.png"))
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


def head_value(page, pattern):
    m = re.search(pattern, page, re.S)
    return html.unescape(m.group(1)).strip() if m else None


site_page = open(os.path.join(out, "site", "index.html"), encoding="utf-8").read()
site_title = head_value(site_page, r"<title>([^<]+)</title>")
site_description = head_value(site_page, r'<meta name="description" content="([^"]*)">')
if not site_title or not site_description:
    sys.exit("site/index.html needs a title and a description in its head: rebuild it with R/16_build_site.R")
with open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write("""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<meta name="description" content="%s">
<meta http-equiv="refresh" content="0; url=site/">
</head><body>
<p><a href="site/">Texas COVID-19 vaccination coverage: the interactive report</a></p>
</body></html>
""" % (html.escape(site_title), html.escape(site_description)))

# link-preview tags for every page, with full addresses
owner, name = repo.split("/")
base = (os.environ.get("PAGES_BASE_URL") or "https://%s.github.io/%s" % (owner.lower(), name)).rstrip("/")
image = base + "/site/preview.png"
tagged = 0
for path in [os.path.join(out, "index.html"), os.path.join(out, "site", "index.html")] + sorted(glob.glob(os.path.join(out, "docs", "*.html"))):
    rel = os.path.relpath(path, out).replace(os.sep, "/")
    url = base + "/" + ("" if rel == "index.html" else "site/" if rel == "site/index.html" else rel)
    page = open(path, encoding="utf-8").read()
    title = head_value(page, r"<title>([^<]+)</title>")
    description = head_value(page, r'<meta name="description" content="([^"]*)">')
    if not title or not description or page.count("</head>") != 1:
        sys.exit("%s needs one head with a title and a description" % rel)
    a = lambda v: html.escape(v, quote=True)
    tags = "\n".join([
        '<link rel="canonical" href="%s">' % a(url),
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Texas COVID-19 vaccination coverage">',
        '<meta property="og:title" content="%s">' % a(title),
        '<meta property="og:description" content="%s">' % a(description),
        '<meta property="og:url" content="%s">' % a(url),
        '<meta property="og:image" content="%s">' % a(image),
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        '<meta property="og:image:alt" content="Map of Texas counties shaded by first-dose COVID-19 vaccination coverage on 9 May 2023">',
        '<meta name="twitter:card" content="summary_large_image">'])
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page.replace("</head>", tags + "\n</head>", 1))
    tagged += 1
print("link-preview tags added to %d pages; site address %s" % (tagged, base))

total = 0
for root, _, files in os.walk(out):
    for name in sorted(files):
        p = os.path.join(root, name)
        total += os.path.getsize(p)
        print("%9.1f KB  %s" % (os.path.getsize(p) / 1024, os.path.relpath(p, out).replace(os.sep, "/")))
print("%d links now point at %s; %.1f MB in all" % (changed, blob, total / 1e6))
