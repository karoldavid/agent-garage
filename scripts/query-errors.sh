#!/bin/bash

# Quick script to query error_logs table from terminal
# Usage: ./scripts/query-errors.sh [command]
# Commands: count, recent, all, by-severity, by-category, table-info

DB_USER="root"
DB_NAME="n8n"
CONTAINER="postgres"

case "${1:-recent}" in
  count)
    echo "📊 Total errors in database:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_errors FROM error_logs;"
    ;;
  
  recent)
    echo "📋 Recent errors (last 10):"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT timestamp, severity, category, LEFT(summary, 50) as summary FROM error_logs ORDER BY created_at DESC LIMIT 10;"
    ;;
  
  all)
    echo "📋 All errors:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT id, timestamp, severity, category, summary, message FROM error_logs ORDER BY created_at DESC;"
    ;;
  
  by-severity)
    echo "📊 Errors by severity:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT severity, COUNT(*) as count FROM error_logs GROUP BY severity ORDER BY count DESC;"
    ;;
  
  by-category)
    echo "📊 Errors by category:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT category, COUNT(*) as count FROM error_logs WHERE category IS NOT NULL GROUP BY category ORDER BY count DESC;"
    ;;
  
  table-info)
    echo "📋 Table structure:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "\d error_logs"
    ;;
  
  detailed)
    echo "📋 Detailed error information:"
    docker compose exec -T $CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT timestamp, severity, category, summary, LEFT(message, 80) as message, error_hash FROM error_logs ORDER BY created_at DESC LIMIT 5;"
    ;;
  
  *)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  count        - Show total number of errors"
    echo "  recent       - Show last 10 errors (default)"
    echo "  all          - Show all errors"
    echo "  by-severity  - Group errors by severity level"
    echo "  by-category  - Group errors by category"
    echo "  table-info   - Show table structure"
    echo "  detailed     - Show detailed error information"
    echo ""
    echo "Examples:"
    echo "  $0 count"
    echo "  $0 recent"
    echo "  $0 by-category"
    ;;
esac

