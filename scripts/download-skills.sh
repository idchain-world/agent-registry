#!/usr/bin/env bash
#
# Download Trail of Bits (and other) skills into agent folders.
# Reads .claude/agents/skills.json manifest, clones repos, copies skill directories.
#
# Usage:
#   ./scripts/download-skills.sh           # Download all skills for all agents
#   ./scripts/download-skills.sh <agent>   # Download skills for a specific agent
#   ./scripts/download-skills.sh --clean   # Remove all downloaded skills
#   ./scripts/download-skills.sh --list    # List configured skills per agent

set -euo pipefail

# Resolve project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
MANIFEST="$AGENTS_DIR/skills.json"
CACHE_DIR="/tmp/claude-skills-cache"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}"
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is required.${NC}"
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: Manifest not found at $MANIFEST${NC}"
    exit 1
fi

# --- Functions ---

clone_repo() {
    local name="$1"
    local url="$2"
    local dest="$CACHE_DIR/$name"

    if [ -d "$dest" ]; then
        echo -e "  ${YELLOW}cached${NC} $name"
    else
        echo -e "  ${BLUE}cloning${NC} $url"
        git clone --depth 1 --quiet "$url" "$dest"
    fi
}

install_skill() {
    local agent="$1"
    local repo_name="$2"
    local plugin="$3"
    local skill="${4:-}"  # Optional: specific sub-skill within a plugin
    local dest_name="${5:-$plugin}"  # Optional: destination directory name

    local repo_dir="$CACHE_DIR/$repo_name"
    local src_base="$repo_dir/plugins/$plugin/skills"
    local dest_base="$AGENTS_DIR/$agent/skills"

    if [ -n "$skill" ]; then
        # Sub-skill: copy specific skill into plugin-named subdirectory
        local src="$src_base/$skill"
        local dest="$dest_base/$dest_name/$skill"

        if [ ! -d "$src" ]; then
            echo -e "    ${RED}not found${NC} $plugin/$skill"
            return 1
        fi

        mkdir -p "$dest"
        cp -r "$src/"* "$dest/" 2>/dev/null || true
        local file_count
        file_count=$(find "$dest" -type f | wc -l | tr -d ' ')
        echo -e "    ${GREEN}installed${NC} $plugin/$skill ($file_count files)"
    else
        # Single skill (same name as plugin)
        local src="$src_base/$plugin"
        local dest="$dest_base/$plugin"

        if [ ! -d "$src" ]; then
            echo -e "    ${RED}not found${NC} $plugin"
            return 1
        fi

        mkdir -p "$dest"
        cp -r "$src/"* "$dest/" 2>/dev/null || true
        local file_count
        file_count=$(find "$dest" -type f | wc -l | tr -d ' ')
        echo -e "    ${GREEN}installed${NC} $plugin ($file_count files)"
    fi
}

download_agent_skills() {
    local agent="$1"
    echo -e "\n${BLUE}[$agent]${NC}"

    # Clean existing skills for this agent
    if [ -d "$AGENTS_DIR/$agent/skills" ]; then
        rm -rf "$AGENTS_DIR/$agent/skills"
    fi
    mkdir -p "$AGENTS_DIR/$agent/skills"

    local entries
    entries=$(jq -r ".agents.\"$agent\" | length" "$MANIFEST")

    for ((i = 0; i < entries; i++)); do
        local repo_key plugin skills_count
        repo_key=$(jq -r ".agents.\"$agent\"[$i].repo" "$MANIFEST")
        plugin=$(jq -r ".agents.\"$agent\"[$i].plugin" "$MANIFEST")
        skills_count=$(jq -r ".agents.\"$agent\"[$i].skills // [] | length" "$MANIFEST")

        # Clone the repo if needed
        local repo_url
        repo_url=$(jq -r ".repos.\"$repo_key\"" "$MANIFEST")
        clone_repo "$repo_key" "$repo_url"

        if [ "$skills_count" -gt 0 ]; then
            # Plugin with specific sub-skills
            for ((j = 0; j < skills_count; j++)); do
                local skill
                skill=$(jq -r ".agents.\"$agent\"[$i].skills[$j]" "$MANIFEST")
                install_skill "$agent" "$repo_key" "$plugin" "$skill" "$plugin"
            done
        else
            # Single-skill plugin
            install_skill "$agent" "$repo_key" "$plugin"
        fi
    done
}

list_skills() {
    echo -e "${BLUE}Configured skills per agent:${NC}\n"
    for agent in $(jq -r '.agents | keys[]' "$MANIFEST"); do
        echo -e "${GREEN}$agent${NC}"
        local entries
        entries=$(jq -r ".agents.\"$agent\" | length" "$MANIFEST")
        for ((i = 0; i < entries; i++)); do
            local plugin skills_count
            plugin=$(jq -r ".agents.\"$agent\"[$i].plugin" "$MANIFEST")
            skills_count=$(jq -r ".agents.\"$agent\"[$i].skills // [] | length" "$MANIFEST")

            if [ "$skills_count" -gt 0 ]; then
                echo "  $plugin/"
                for ((j = 0; j < skills_count; j++)); do
                    local skill
                    skill=$(jq -r ".agents.\"$agent\"[$i].skills[$j]" "$MANIFEST")
                    echo "    - $skill"
                done
            else
                echo "  - $plugin"
            fi
        done
        echo
    done
}

clean_skills() {
    echo -e "${YELLOW}Cleaning downloaded skills...${NC}"
    for agent in $(jq -r '.agents | keys[]' "$MANIFEST"); do
        if [ -d "$AGENTS_DIR/$agent/skills" ]; then
            rm -rf "$AGENTS_DIR/$agent/skills"
            echo -e "  ${GREEN}cleaned${NC} $agent/skills/"
        fi
    done
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"
        echo -e "  ${GREEN}cleaned${NC} repo cache"
    fi
    echo -e "${GREEN}Done.${NC}"
}

count_skills() {
    local total=0
    for agent in $(jq -r '.agents | keys[]' "$MANIFEST"); do
        if [ -d "$AGENTS_DIR/$agent/skills" ]; then
            local count
            count=$(find "$AGENTS_DIR/$agent/skills" -name "SKILL.md" | wc -l | tr -d ' ')
            total=$((total + count))
        fi
    done
    echo "$total"
}

# --- Main ---

case "${1:-}" in
    --clean)
        clean_skills
        ;;
    --list)
        list_skills
        ;;
    --help|-h)
        echo "Usage: $0 [agent|--clean|--list|--help]"
        echo ""
        echo "  (no args)    Download all skills for all agents"
        echo "  <agent>      Download skills for a specific agent"
        echo "  --clean      Remove all downloaded skills and cache"
        echo "  --list       List configured skills per agent"
        echo ""
        echo "Manifest: .claude/agents/skills.json"
        ;;
    "")
        echo -e "${BLUE}Downloading skills for all agents...${NC}"
        mkdir -p "$CACHE_DIR"

        for agent in $(jq -r '.agents | keys[]' "$MANIFEST"); do
            download_agent_skills "$agent"
        done

        # Clean cache
        rm -rf "$CACHE_DIR"

        total=$(count_skills)
        echo -e "\n${GREEN}Done. $total skills installed across $(jq -r '.agents | keys | length' "$MANIFEST") agents.${NC}"
        ;;
    *)
        # Specific agent
        local_agent="$1"
        if ! jq -e ".agents.\"$local_agent\"" "$MANIFEST" &>/dev/null; then
            echo -e "${RED}Error: Agent '$local_agent' not found in manifest.${NC}"
            echo "Available agents: $(jq -r '.agents | keys[]' "$MANIFEST" | tr '\n' ' ')"
            exit 1
        fi

        echo -e "${BLUE}Downloading skills for $local_agent...${NC}"
        mkdir -p "$CACHE_DIR"
        download_agent_skills "$local_agent"
        rm -rf "$CACHE_DIR"

        total=$(count_skills)
        echo -e "\n${GREEN}Done.${NC}"
        ;;
esac
