#!/bin/bash

# =============================================
# LOG FILE ANALYZER
# =============================================
# Analyzes web server logs and generates reports
# Usage: ./log_analyzer.sh [logfile]
# =============================================

# --------------------------
# INITIALIZATION
# --------------------------
set -e # Exit on error

# Check for input file
if [ $# -eq 0 ]; then
    echo "ERROR: No log file specified"
    echo "Usage: $0 <path-to-logfile>"
    exit 1
fi

LOG_FILE="$1"
REPORT_FILE="log_analysis_report_$(date +%Y%m%d).txt"

# Validate log file
if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: File '$LOG_FILE' not found!"
    exit 1
fi

# --------------------------
# ANALYSIS FUNCTIONS
# --------------------------

# Initialize counters
TOTAL_REQUESTS=0
GET_REQUESTS=0
POST_REQUESTS=0
FAILED_REQUESTS=0

analyze_requests() {
    echo "1. REQUEST ANALYSIS"
    echo "==================="
    
    TOTAL_REQUESTS=$(wc -l < "$LOG_FILE")
    GET_REQUESTS=$(grep -c '"GET ' "$LOG_FILE")
    POST_REQUESTS=$(grep -c '"POST ' "$LOG_FILE")
    FAILED_REQUESTS=$(awk '$9 ~ /^[45][0-9][0-9]$/ {count++} END {print count}' "$LOG_FILE")
    FAIL_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($FAILED_REQUESTS/$TOTAL_REQUESTS)*100}")

    echo "Total requests: $TOTAL_REQUESTS"
    echo "GET requests: $GET_REQUESTS"
    echo "POST requests: $POST_REQUESTS"
    echo ""
}

analyze_ips() {
    echo "2. IP ADDRESS ANALYSIS"
    echo "======================"
    
    echo "Unique IP addresses: $(awk '{print $1}' "$LOG_FILE" | sort -u | wc -l)"
    echo ""
    
    echo "Top 10 IPs by request volume:"
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10
    echo ""
}

analyze_status_codes() {
    echo "3. STATUS CODE ANALYSIS"
    echo "======================="
    
    echo "Failed requests (4xx/5xx): $FAILED_REQUESTS ($FAIL_PERCENT%)"
    echo ""
    
    echo "Status code distribution:"
    awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -nr
    echo ""
}

analyze_temporal_patterns() {
    echo "4. TEMPORAL ANALYSIS"
    echo "===================="
    
    echo "Requests by hour:"
    awk -F: '{print $2":00"}' "$LOG_FILE" | sort | uniq -c
    echo ""
    
    echo "Daily request averages:"
    awk '{split($4,date,"["); split(date[2],d,":"); print d[1]}' "$LOG_FILE" | 
        sort | uniq -c | 
        awk '{sum+=$1; days++; print $2 ": " $1 " requests"} 
             END {print "Average: " int(sum/days) " requests/day"}'
    echo ""
    
    echo "Days with most failures:"
    awk '$9 ~ /^[45][0-9][0-9]$/ {split($4,date,"["); split(date[2],d,":"); print d[1]}' "$LOG_FILE" |
        sort | uniq -c | sort -nr | head -5
    echo ""
}

generate_suggestions() {
    echo "5. RECOMMENDATIONS"
    echo "=================="
    
    # Get peak hour
    PEAK_HOUR=$(awk -F: '{print $2":00"}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -1)
    
    # Get worst day for failures
    WORST_DAY=$(awk '$9 ~ /^[45][0-9][0-9]$/ {split($4,date,"["); split(date[2],d,":"); print d[1]}' "$LOG_FILE" |
        sort | uniq -c | sort -nr | head -1)
    
    echo "1. Peak traffic hour: $PEAK_HOUR - consider scaling resources during this time"
    echo "2. Highest failure day: $WORST_DAY - investigate server issues on this day"
    echo "3. Top IPs making requests may need monitoring for suspicious activity"
    echo "4. Review endpoints generating 404 errors to fix broken links"
    echo "5. Consider caching for frequently accessed resources during peak hours"
    echo ""
}

# --------------------------
# MAIN EXECUTION
# --------------------------
{
    echo "LOG ANALYSIS REPORT"
    echo "Generated: $(date)"
    echo "Analyzed file: $LOG_FILE"
    echo "========================================"
    echo ""
    
    analyze_requests
    analyze_ips
    analyze_status_codes
    analyze_temporal_patterns
    generate_suggestions
    
    echo "End of report"
} > "$REPORT_FILE"

echo "Analysis complete! Report saved to $REPORT_FILE"
