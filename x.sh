#!/bin/bash

# Check input
if [ -z "$1" ]; then
    echo "Usage: $0 <Series_URL>"
    exit 1
fi

SERIES_URL="$1"
# Extract the base domain dynamically (e.g., https://watchanimeworld.net)
BASE_DOMAIN=$(echo "$SERIES_URL" | grep -oP 'https?://[^/]+')
AJAX_URL="${BASE_DOMAIN}/wp-admin/admin-ajax.php"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0"

TMP_MAIN="main_page.html"
TMP_SEASON="season_part.html"
ALL_EPISODES="all_episodes_raw.txt"

# Clean up previous runs
rm -f "$ALL_EPISODES" "$TMP_MAIN" "$TMP_SEASON"

echo "------------------------------------------------"
echo "Phase 1: Analyzing Series Page..."
echo "------------------------------------------------"

# 1. Fetch the Main Page
curl -s -L -A "$UA" "$SERIES_URL" -o "$TMP_MAIN"

# 2. Extract Series Title
TITLE=$(grep -oP '<title>\K.*?(?=</title>)' "$TMP_MAIN" | sed 's/ - Watch.*//')
echo "Target: $TITLE"

# 3. Extract the internal "Post ID" (Required for the 'secret' request)
# Look for data-post="1234"
POST_ID=$(grep -oP 'data-post="\K[0-9]+' "$TMP_MAIN" | head -n 1)

if [ -z "$POST_ID" ]; then
    echo "⚠️  Could not find Series ID (data-post). Falling back to simple scrape..."
    # If we can't find the ID, we just grep the main page like before
    cat "$TMP_MAIN" > "$ALL_EPISODES"
else
    echo "Detected Series ID: $POST_ID"
    
    # 4. Find all available seasons listed in the dropdown/tabs
    # Look for data-season="1", data-season="2", etc.
    echo "Identifying available seasons..."
    grep -oP 'data-season="\K[0-9]+' "$TMP_MAIN" | sort -u -n > seasons_list.txt
    
    SEASON_COUNT=$(wc -l < seasons_list.txt)
    echo "Found $SEASON_COUNT seasons defined in the menu."
    
    echo "------------------------------------------------"
    echo "Phase 2: Fetching data for all seasons..."
    echo "------------------------------------------------"
    
    # 5. Loop through every season found and request its episodes
    while read -r SEASON_NUM; do
        printf "  > Downloading Season %s data... " "$SEASON_NUM"
        
        # This simulates the AJAX call the browser makes when you click a season
        # action=action_select_season is the standard for this WordPress theme
        curl -s -X POST "$AJAX_URL" \
             -A "$UA" \
             -d "action=action_select_season&season=$SEASON_NUM&post=$POST_ID" \
             -o "$TMP_SEASON"
             
        # Append this season's HTML to our master file
        cat "$TMP_SEASON" >> "$ALL_EPISODES"
        echo "Done."
        
        # Be nice to the server, sleep briefly
        sleep 0.2
    done < seasons_list.txt
    
    # Add the main page too (sometimes contains the latest season already)
    cat "$TMP_MAIN" >> "$ALL_EPISODES"
fi

echo "------------------------------------------------"
echo "Phase 3: Parsing & Sorting..."
echo "------------------------------------------------"

# 6. Extract URLs from the combined data and Parse
grep -oP 'href="\K[^"]*/episode/[^"]*-[0-9]+x[0-9]+/?' "$ALL_EPISODES" | sort -u > url_list.txt

awk '
{
    url = $0
    sub(/\/$/, "", url) # Remove trailing slash

    # Regex to capture -SxN (e.g. -7x21)
    match(url, /-([0-9]+)x([0-9]+)$/, arr)
    
    if (arr[1] != "") {
        season = arr[1] + 0
        episode = arr[2] + 0
        
        urls[season, episode] = $0
        count[season]++
        if (episode > max_ep[season]) max_ep[season] = episode
        seasons[season] = 1
    }
}
END {
    n = asorti(seasons, sorted_seasons)
    
    print ""
    print "FINAL RESULTS FOR: " "'"$TITLE"'"
    print "========================================"
    
    for (i = 1; i <= n; i++) {
        s = sorted_seasons[i]
        printf "Season %d : %d episodes\n", s, count[s]
        print "----------------------------------------"
        for (e = 1; e <= max_ep[s]; e++) {
            if (urls[s, e] != "") {
                print urls[s, e]
            }
        }
        print "" 
    }
}' url_list.txt

# Cleanup
rm -f "$TMP_MAIN" "$TMP_SEASON" "$ALL_EPISODES" seasons_list.txt url_list.txt
