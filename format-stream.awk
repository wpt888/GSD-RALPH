#!/usr/bin/awk -f
# Filters Claude stream-json output into human-readable progress

/"tool_use"/ {
  if (match($0, /"name":"([^"]*)"/, m)) {
    tool = m[1]
    if (tool == "Read" || tool == "Edit" || tool == "Write") {
      if (match($0, /"file_path":"([^"]*)"/, f))
        printf "  [%s] %s\n", tool, f[1]
      else
        printf "  [%s]\n", tool
    } else if (tool == "Bash") {
      if (match($0, /"command":"([^"]*)"/, c))
        printf "  [Bash] %.120s\n", c[1]
      else
        print "  [Bash]"
    } else if (tool == "Glob" || tool == "Grep") {
      if (match($0, /"pattern":"([^"]*)"/, p))
        printf "  [%s] %s\n", tool, p[1]
      else
        printf "  [%s]\n", tool
    } else if (tool == "Skill") {
      if (match($0, /"skill":"([^"]*)"/, s))
        printf "  [Skill] %s\n", s[1]
      else
        print "  [Skill]"
    } else {
      printf "  [%s]\n", tool
    }
  }
  next
}

/"type":"assistant"/ && /"type":"text"/ {
  if (match($0, /"text":"([^"]*)"/, t)) {
    gsub(/\\n/, "\n", t[1])
    if (t[1] != "") print t[1]
  }
  next
}

/"type":"result"/ {
  turns = ""; dur = ""; cost = ""
  if (match($0, /"num_turns":([0-9]+)/, n)) turns = n[1]
  if (match($0, /"duration_ms":([0-9]+)/, d)) dur = d[1]
  if (match($0, /"total_cost_usd":([0-9.]+)/, c)) cost = c[1]
  if (dur != "") {
    secs = int(dur / 1000)
    printf "  -- Done: %s turns, %ds, $%s --\n", turns, secs, cost
  }
}
