#!/usr/bin/env bash
# Render the session's memory folder as a single searchable HTML page.
# Reads only frontmatter + the Why line, so it costs no model tokens.
# Usage: memories-report.sh [--out PATH] [--open] [--dir MEMORY_DIR]
set -u

out="$HOME/claude-memories.html"
open=0
memdir=""

while [ $# -gt 0 ]; do
  case $1 in
    --out)  out=$2; shift 2 ;;
    --dir)  memdir=$2; shift 2 ;;
    --open) open=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --- Locate the memory dir (same home/project resolution as statusline.sh) ---
if [ -z "$memdir" ]; then
  cwd=$(pwd -W 2>/dev/null) || cwd=$PWD   # -W gives the Windows form (C:/...)
  cwd=${cwd//\\//}
  cwd=${cwd%/}
  projkey=${cwd//:/-}
  projkey=${projkey//\//-}
  for h in "$HOME" "${USERPROFILE//\\//}" "$HOMEDRIVE$HOMEPATH"; do
    [ -n "$h" ] || continue
    d="${h%/}/.claude/projects/$projkey/memory"
    [ -d "$d" ] && { memdir=$d; break; }
  done
fi
[ -n "$memdir" ] && [ -d "$memdir" ] || { echo "no memory dir found for $PWD" >&2; exit 1; }
case $out in /*|?:*) ;; *) out="$PWD/$out" ;; esac

# --- Helpers ---
# These return through $R instead of $(...): a subshell fork costs ~0.5s on this
# machine, and the naive version forked ~270 times (over two minutes per run).
R=""
esc() {                       # HTML-escape
  local s=$1
  s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}
  R=$s
}
md() {                        # escape + `code` + **bold**
  esc "$1"
  local s=$R
  while [[ $s == *'`'*'`'* ]]; do
    s=${s/\`/<code>}
    s=${s/\`/<\/code>}
  done
  while [[ $s == *'**'*'**'* ]]; do
    s=${s/\*\*/<b>}
    s=${s/\*\*/<\/b>}
  done
  R=$s
}
unquote() {                   # strip wrapping quotes from a frontmatter value
  local s=$1
  s=${s#\"}; s=${s%\"}; s=${s#\'}; s=${s%\'}
  R=$s
}

# --- Titles + hooks from MEMORY.md:  - [Title](file.md) - hook ---
declare -A TITLE HOOK
if [ -f "$memdir/MEMORY.md" ]; then
  idx_re='^-[[:space:]]*\[([^]]*)\]\(([^)]*)\)(.*)$'   # must be a var: [[ ]] mangles \)
  while IFS= read -r line; do
    [[ $line =~ $idx_re ]] || continue
    f=${BASH_REMATCH[2]}
    TITLE[$f]=${BASH_REMATCH[1]}
    h=${BASH_REMATCH[3]}
    h=${h#* }                 # drop the leading separator
    HOOK[$f]=$h
  done < "$memdir/MEMORY.md"
fi

# --- Collect one record per memory ---
names=(); files=(); types=(); descs=(); whys=()
total=0
for f in "$memdir"/*.md; do
  [ -e "$f" ] || continue
  base=${f##*/}
  [ "$base" = "MEMORY.md" ] && continue

  type=""; desc=""; why=""; fm=0; body=0
  while IFS= read -r line; do
    if [ "$line" = "---" ]; then fm=$((fm + 1)); [ $fm -ge 2 ] && body=1; continue; fi
    if [ $fm -eq 1 ]; then
      # type: is nested under metadata:, so trim indentation before matching.
      # node_type: deliberately does not match the type:* pattern.
      k=${line#"${line%%[![:space:]]*}"}
      case $k in
        description:*) v=${k#description:}; v=${v# }; unquote "$v"; desc=$R ;;
        type:*)        v=${k#type:};        v=${v# }; unquote "$v"; type=$R ;;
      esac
    elif [ $body -eq 1 ] && [ -z "$why" ]; then
      case $line in \*\*Why:\*\**) why=${line#\*\*Why:\*\*}; why=${why# } ;; esac
    fi
  done < "$f"

  [ -z "$type" ] && type="other"
  slug=${base%.md}
  name=${TITLE[$base]:-$slug}
  [ -z "$desc" ] && desc=${HOOK[$base]:-}

  names+=("$name"); files+=("$base"); types+=("$type")
  descs+=("$desc"); whys+=("$why")
  total=$((total + 1))
done

# --- Render ---
{
cat <<'HEAD'
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Claude memories</title>
<style>
:root{--bg:#0b0e14;--card:#141922;--card2:#1a2130;--line:#242c3a;--txt:#e6eaf2;
--dim:#8b93a7;--sky:#7dd3fc;--teal:#14b8a6;--orange:#fb923c;--yellow:#eab308;--violet:#a78bfa}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);padding:32px 24px 64px;
font:15px/1.6 "Segoe UI",system-ui,sans-serif}
.wrap{max-width:1040px;margin:0 auto}
h1{font-size:25px;margin:0 0 4px;color:var(--sky);font-weight:600}
.sub{color:var(--dim);margin:0 0 22px;font-size:13.5px}
.tools{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:20px}
#q{flex:1;min-width:240px;background:var(--card);border:1px solid var(--line);color:var(--txt);
padding:10px 14px;border-radius:8px;font-size:14px;outline:none}
#q:focus{border-color:var(--sky)}
.fbtn{background:var(--card);border:1px solid var(--line);color:var(--dim);padding:8px 14px;
border-radius:8px;cursor:pointer;font-size:13px}
.fbtn:hover{color:var(--txt)}.fbtn.on{border-color:var(--sky);color:var(--sky)}
h2{font-size:14px;letter-spacing:.08em;text-transform:uppercase;color:var(--dim);
margin:32px 0 12px;border-bottom:1px solid var(--line);padding-bottom:8px}
h2 .n{color:var(--sky)}
.card{background:var(--card);border:1px solid var(--line);border-left:3px solid var(--line);
border-radius:10px;padding:13px 18px;margin-bottom:9px}
.card.feedback{border-left-color:var(--orange)}
.card.project{border-left-color:var(--teal)}
.card.ticket{border-left-color:var(--yellow)}
.card.reference{border-left-color:var(--violet)}
.card h3{margin:0 0 5px;font-size:15px;font-weight:600;display:flex;gap:10px;
align-items:baseline;flex-wrap:wrap}
.file{font-family:Consolas,monospace;font-size:11.5px;color:var(--dim);font-weight:400}
.card p{margin:0;color:#c3cad8;font-size:14px}
.why{margin-top:5px;color:var(--dim);font-size:13px}
.why b{color:var(--yellow)}
code{font-family:Consolas,monospace;background:var(--card2);padding:1px 5px;border-radius:4px;
font-size:12.5px;color:var(--sky)}
.empty{color:var(--dim);display:none;padding:18px 0}
footer{margin-top:40px;color:var(--dim);font-size:12.5px;border-top:1px solid var(--line);padding-top:14px}
</style></head><body><div class="wrap">
HEAD

printf '<h1>Claude memories</h1>\n'
esc "$memdir"; printf -v stamp '%(%Y-%m-%d %H:%M)T' -1
printf '<p class="sub">%s memories in <code>%s</code> &middot; generated %s</p>\n' \
  "$total" "$R" "$stamp"

cat <<'TOOLS'
<div class="tools">
<input id="q" placeholder="Search…">
<button class="fbtn on" data-f="all">All</button>
<button class="fbtn" data-f="feedback">Rules</button>
<button class="fbtn" data-f="ticket">Tickets</button>
<button class="fbtn" data-f="project">Projects</button>
<button class="fbtn" data-f="reference">Reference</button>
</div>
<p class="empty" id="empty">Nothing matches.</p>
TOOLS

emit_section() {
  local want=$1 heading=$2 i n=0
  for i in "${!names[@]}"; do
    [ "${types[$i]}" = "$want" ] || continue
    n=$((n + 1))
  done
  [ $n -eq 0 ] && return
  printf '<h2>%s <span class="n">(%d)</span></h2>\n' "$heading" "$n"
  local title file body
  for i in "${!names[@]}"; do
    [ "${types[$i]}" = "$want" ] || continue
    esc "${names[$i]}"; title=$R
    esc "${files[$i]}"; file=$R
    md  "${descs[$i]}"; body=$R
    printf '<div class="card %s"><h3>%s<span class="file">%s</span></h3><p>%s</p>' \
      "$want" "$title" "$file" "$body"
    if [ -n "${whys[$i]}" ]; then
      md "${whys[$i]}"
      printf '<p class="why"><b>Why:</b> %s</p>' "$R"
    fi
    printf '</div>\n'
  done
}

# project memories whose file starts with cls- are per-ticket state
for i in "${!files[@]}"; do
  case ${files[$i]} in cls-*) [ "${types[$i]}" = "project" ] && types[$i]="ticket" ;; esac
done

emit_section feedback  "Rules for how I work"
emit_section ticket    "Ticket state"
emit_section project   "Projects &amp; codebase gotchas"
emit_section reference "Machine &amp; environment facts"
emit_section other     "Uncategorised"

cat <<'TAIL'
<footer>Regenerate with <code>~/.claude/bin/memories-report.sh --open</code>. Text comes from each
file's <code>description:</code> frontmatter and its <code>**Why:**</code> line — edit the
<code>.md</code> to change a card.</footer>
</div>
<script>
const q=document.getElementById('q'),cards=[...document.querySelectorAll('.card')],
secs=[...document.querySelectorAll('h2')],empty=document.getElementById('empty');
let filter='all';
function apply(){const t=q.value.trim().toLowerCase();let shown=0;
cards.forEach(c=>{const ok=(filter==='all'||c.classList.contains(filter))&&
(!t||c.textContent.toLowerCase().includes(t));c.style.display=ok?'':'none';if(ok)shown++;});
secs.forEach(h=>{let n=h.nextElementSibling,any=false;
while(n&&n.classList.contains('card')){if(n.style.display!=='none')any=true;n=n.nextElementSibling;}
h.style.display=any?'':'none';});
empty.style.display=shown?'none':'block';}
q.addEventListener('input',apply);
document.querySelectorAll('.fbtn').forEach(b=>b.addEventListener('click',()=>{
document.querySelectorAll('.fbtn').forEach(x=>x.classList.remove('on'));
b.classList.add('on');filter=b.dataset.f;apply();}));
</script></body></html>
TAIL
} > "$out"

echo "$total memories -> $out"
[ $open -eq 1 ] && start "" "$(cygpath -w "$out" 2>/dev/null || echo "$out")" 2>/dev/null
exit 0
