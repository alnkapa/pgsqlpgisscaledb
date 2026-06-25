
calculate_postgresql_params() {
    local mem_mb=$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)
    if [ -z "$PG_SHARED_BUFFERS" ]; then                
        PG_SHARED_BUFFERS=$((mem_mb / 4))
        [ $PG_SHARED_BUFFERS -lt 40 ] && PG_SHARED_BUFFERS=40
        [ $PG_SHARED_BUFFERS -gt 40000 ] && PG_SHARED_BUFFERS=40000
    fi
    
    if [ -z "$PG_EFFECTIVE_CACHE_SIZE" ]; then
        PG_EFFECTIVE_CACHE_SIZE=$((mem_mb * 3 / 4))
    fi
    PG_MAX_CONNECTIONS=${PG_MAX_CONNECTIONS:-100}
    if [ -z "$PG_WORK_MEM" ]; then
        PG_WORK_MEM=$((($mem_mb - $PG_SHARED_BUFFERS) / ($PG_MAX_CONNECTIONS * 2)))
        [ $PG_WORK_MEM -lt 4 ] && PG_WORK_MEM=4
    fi
    
    if [ -z "$PG_MAINTENANCE_WORK_MEM" ]; then
        PG_MAINTENANCE_WORK_MEM=$((PG_SHARED_BUFFERS / 4))
        [ $PG_MAINTENANCE_WORK_MEM -gt 2048 ] && PG_MAINTENANCE_WORK_MEM=2048
    fi
}

calculate_postgresql_params