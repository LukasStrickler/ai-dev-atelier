#!/bin/bash
# Cleanup temporary PDF files from research downloads
# Only removes PDFs from .ada/temp/research/downloads/
# Preserves evidence cards, MD files, and references.json

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/research-utils.sh"

# Parse command line arguments
DRY_RUN=false
UPDATE_REFERENCES=false
CLEAR_ALL=false
OLDER_THAN_DAYS=""
TOPIC_FILTER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      CLEAR_ALL=true
      shift
      ;;
    --older-than)
      OLDER_THAN_DAYS="$2"
      shift 2
      ;;
    --topic)
      TOPIC_FILTER="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --update-references)
      UPDATE_REFERENCES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--all] [--older-than <days>] [--topic <topic>] [--dry-run] [--update-references]"
      exit 1
      ;;
  esac
done

# Find PDFs to delete based on criteria
find_pdfs_to_delete() {
  local pdfs_to_delete=()
  
  if [ "$CLEAR_ALL" = true ]; then
    # Delete all PDFs
    if [ -d "$DOWNLOADS_DIR" ]; then
      while IFS= read -r -d '' pdf_file; do
        pdfs_to_delete+=("$pdf_file")
      done < <(find "$DOWNLOADS_DIR" -name "*.pdf" -type f -print0 2>/dev/null)
    fi
  elif [ -n "$OLDER_THAN_DAYS" ]; then
    # Delete PDFs older than N days
    if [ -d "$DOWNLOADS_DIR" ]; then
      while IFS= read -r -d '' pdf_file; do
        local file_age
        file_age=$(find "$pdf_file" -type f -mtime +"$OLDER_THAN_DAYS" 2>/dev/null)
        if [ -n "$file_age" ]; then
          pdfs_to_delete+=("$pdf_file")
        fi
      done < <(find "$DOWNLOADS_DIR" -name "*.pdf" -type f -print0 2>/dev/null)
    fi
  elif [ -n "$TOPIC_FILTER" ]; then
    # Delete PDFs for specific topic (based on references.json)
    if [ -d "$EVIDENCE_CARDS_DIR" ]; then
      for card_dir in "$EVIDENCE_CARDS_DIR"/*; do
        if [ -d "$card_dir" ]; then
          local ref_file="${card_dir}/references.json"
          if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
            local topic=$(jq -r '.topic // ""' "$ref_file" 2>/dev/null)
            if [[ "$topic" == *"$TOPIC_FILTER"* ]]; then
              # Get PDF paths from this references.json
              while IFS= read -r pdf_path; do
                if [ -f "$pdf_path" ]; then
                  pdfs_to_delete+=("$pdf_path")
                fi
              done < <(jq -r '.papers[] | select(.pdf_path != null) | .pdf_path' "$ref_file" 2>/dev/null)
            fi
          fi
        fi
      done
    fi
  else
    echo "Error: Must specify --all, --older-than <days>, or --topic <topic>"
    exit 1
  fi
  
  # Remove duplicates
  printf '%s\n' "${pdfs_to_delete[@]}" | sort -u
}

# Update references.json to mark PDFs as cleared
update_references_for_pdfs() {
  local pdf_file="$1"
  local pdf_filename=$(basename "$pdf_file")
  
  # Find all references.json files and update them
  if [ -d "$EVIDENCE_CARDS_DIR" ]; then
    for card_dir in "$EVIDENCE_CARDS_DIR"/*; do
      if [ -d "$card_dir" ]; then
        local ref_file="${card_dir}/references.json"
        if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
          # Check if this references.json references this PDF
          local paper_id=$(jq -r --arg pdf_path "$pdf_file" '.papers[] | select(.pdf_path == $pdf_path) | .id' "$ref_file" 2>/dev/null)
          if [ -n "$paper_id" ]; then
            # Mark PDF as cleared
            jq --arg id "$paper_id" \
              '(.papers[] | select(.id == $id) | .pdf_cleared) = true' \
              "$ref_file" > "${ref_file}.tmp" && mv "${ref_file}.tmp" "$ref_file"
          fi
        fi
      fi
    done
  fi
}

# Main cleanup function
main() {
  # Check if downloads directory exists
  if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "📁 Downloads directory not found: $DOWNLOADS_DIR"
    echo "   No PDFs to clean up"
    exit 0
  fi
  
  echo "🧹 Cleaning up research PDF files..."
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No files will be deleted"
    echo ""
  fi
  
  # Find PDFs to delete
  local pdfs_to_delete
  pdfs_to_delete=$(find_pdfs_to_delete)
  local count=$(echo "$pdfs_to_delete" | grep -c . || echo "0")
  
  if [ "$count" -eq 0 ]; then
    echo "✅ No PDFs found matching criteria"
    exit 0
  fi
  
  echo "📄 Found $count PDF(s) to delete:"
  echo ""
  
  local deleted=0
  while IFS= read -r pdf_file; do
    if [ -n "$pdf_file" ] && [ -f "$pdf_file" ]; then
      local filename=$(basename "$pdf_file")
      local size=$(du -h "$pdf_file" 2>/dev/null | cut -f1 || echo "unknown")
      
      if [ "$DRY_RUN" = true ]; then
        echo "   [DRY RUN] Would delete: $filename ($size)"
      else
        if rm -f "$pdf_file" 2>/dev/null; then
          echo "   ✅ Deleted: $filename ($size)"
          deleted=$((deleted + 1))
          
          # Update references.json if requested
          if [ "$UPDATE_REFERENCES" = true ]; then
            update_references_for_pdfs "$pdf_file"
          fi
        else
          echo "   ❌ Failed to delete: $filename"
        fi
      fi
    fi
  done <<< "$pdfs_to_delete"
  
  echo ""
  if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN complete - $count PDF(s) would be deleted"
  else
    echo "✅ Cleanup complete! Deleted $deleted PDF(s)"
    
    # Count remaining PDFs
    local remaining=0
    if [ -d "$DOWNLOADS_DIR" ]; then
      remaining=$(find "$DOWNLOADS_DIR" -name "*.pdf" -type f | wc -l | tr -d ' ')
    fi
    echo "📊 Remaining PDFs: $remaining"
    echo ""
    echo "💡 Note: Evidence cards, MD files, and references.json are preserved"
    echo "   PDFs can be re-downloaded using URLs in references.json"
  fi
}

# Run main function
main

