#!/bin/bash
set -euo pipefail

# =============================================================================
# Container Initialization Script - Enhanced Self-Healing System
# =============================================================================

# =============================================================================
# Logging System Initialization
# =============================================================================
LOG_FILE="/hasura-project/05-logs/hasura/init-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[INIT][START] $(date '+%Y-%m-%d %T.%3N')"
echo "[VERSION] Enhanced Init System v3.1"

# =============================================================================
# Deep Script Validation System
# =============================================================================

# 7-Layer Validation Framework
validate_script() {
    local script_path=$1
    local -a errors=()
    
    # Layer 1: Existence Check
    [ -f "$script_path" ] || errors+=("101:File not found")
    
    # Layer 2: Minimum Size (200 bytes)
    [ $(wc -c < "$script_path") -ge 200 ] || errors+=("102:File too small")
    
    # Layer 3: Shebang Validation
    head -n1 "$script_path" | grep -qE '^#!.*(bash|sh)' || errors+=("103:Invalid shebang")
    
    # Layer 4: Line Ending Check
    grep -q $'\r' "$script_path" && errors+=("104:CRLF detected")
    
    # Layer 5: Syntax Validation
    bash -n "$script_path" &>/dev/null || errors+=("105:Syntax error")
    
    # Layer 6: Safety Flags
    grep -q 'set -e' "$script_path" || errors+=("106:Missing 'set -e'")
    grep -q 'set -o pipefail' "$script_path" || errors+=("107:Missing 'set -o pipefail'")
    
    # Layer 7: Checksum Verification
    if [ -f "${script_path}.sha256" ]; then
        sha256sum -c "${script_path}.sha256" --quiet || errors+=("108:Checksum mismatch")
    fi
    
    # Error Reporting
    if [ ${#errors[@]} -gt 0 ]; then
        echo "[VALIDATE] Found ${#errors[@]} issues:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    return 0
}

# Secure Repair Protocol
repair_script() {
    local src=$1
    local dest=$2
    
    echo "[REPAIR] Initiating repair for $(basename "$src")"
    
    # Create Isolated Repair Zone
    local repair_dir=$(mktemp -d)
    local repair_file="${repair_dir}/$(basename "$src")"
    echo "[REPAIR] Isolation zone: $repair_dir"
    
    # Phase 1: Copy to Isolation Zone
    cp "$src" "$repair_file" || return 201
    
    # Phase 2: Repair Sequence
    # Step 1: Fix line endings
    sed -i 's/\r$//' "$repair_file" || return 202
    
    # Step 2: Ensure shebang
    if ! head -n1 "$repair_file" | grep -q '^#!'; then
        sed -i '1i #!/bin/bash' "$repair_file" || return 203
    fi
    
    # Step 3: Add safety flags if missing
    if ! grep -q 'set -e' "$repair_file"; then
        # Insert after shebang
        sed -i '2i set -e' "$repair_file" || return 204
    fi
    
    if ! grep -q 'set -o pipefail' "$repair_file"; then
        # Insert after set -e
        sed -i '3i set -o pipefail' "$repair_file" || return 205
    fi
    
    # Phase 3: Post-Repair Validation
    echo "[REPAIR] Validating repaired script"
    validate_script "$repair_file" || return 206
    
    # Phase 4: Deployment to Target
    mkdir -p "$(dirname "$dest")"
    cp "$repair_file" "$dest" && chmod +x "$dest" || return 207
    
    # Phase 5: Checksum Generation
    sha256sum "$dest" > "${dest}.sha256" || echo "[WARN] Failed to create checksum"
    
    rm -rf "$repair_dir"
    echo "[REPAIR] Repair completed successfully"
    return 0
}

# Script Integrity Assurance System
ensure_script_integrity() {
    local source_path="$1"
    local backup_path="$2"
    local script_name=$(basename "$source_path")
    
    echo "[SCRIPT] Verifying $script_name integrity"
    
    # Scenario 1: Primary Healthy
    if validate_script "$source_path"; then
        echo "[SCRIPT] Primary $script_name validated"
        return 0
    fi
    
    # Scenario 2: Backup Healthy
    if [ -f "$backup_path" ] && validate_script "$backup_path"; then
        echo "[RECOVERY] Restoring $script_name from valid backup"
        cp -f "$backup_path" "$source_path" || {
            echo "[ERROR][CODE:301] Failed to restore from backup"
            return 301
        }
        chmod +x "$source_path" || {
            echo "[ERROR][CODE:302] Permission update failed"
            return 302
        }
        
        # Post-restoration validation
        if validate_script "$source_path"; then
            echo "[RECOVERY] Restoration successful - $script_name healthy"
            return 0
        else
            echo "[ERROR][CODE:303] Post-restoration validation failed"
            return 303
        fi
    fi
    
    # Scenario 3: Dual Corruption
    echo "[CRITICAL] Dual corruption detected for $script_name - initiating repair"
    if repair_script "$source_path" "$backup_path"; then
        echo "[REPAIR-SUCCESS] $script_name repaired in backup location"
        
        # Deploy repaired version to primary
        cp -f "$backup_path" "$source_path" || {
            echo "[ERROR][CODE:304] Failed to deploy to primary"
            return 304
        }
        chmod +x "$source_path" || {
            echo "[ERROR][CODE:305] Permission update failed"
            return 305
        }
        
        # Final validation
        if validate_script "$source_path"; then
            echo "[REPAIR-SUCCESS] Primary $script_name restored and validated"
            return 0
        else
            echo "[ERROR][CODE:306] Post-repair validation failed"
            return 306
        fi
    else
        echo "[CRITICAL][CODE:307] Repair failed for $script_name"
        return 307
    fi
}

# =============================================================================
# Self-Repair Subsystem (init.sh specific)
# =============================================================================

# Self-Repair Protocol
handle_self_repair() {
    local source_path="/hasura-project/init-hasura.sh"
    local backup_path="/hasura-project/01-config/hasura/dos2unix/init-hasura.sh"
    
    echo "[SELF-REPAIR] Initiating self-repair protocol"
    
    # Create Isolation Zone
    local repair_dir=$(mktemp -d)
    local repair_file="${repair_dir}/init-hasura.sh"
    echo "[SELF-REPAIR] Isolation zone: $repair_dir"
    
    # Capture current script state
    cp "$source_path" "$repair_file" || {
        echo "[SELF-REPAIR-ERROR][CODE:601] Failed to capture running script"
        return 601
    }
    
    # Execute Repair Protocol
    if ! repair_script "$repair_file" "$repair_file"; then
        echo "[SELF-REPAIR-ERROR][CODE:601] Repair sequence failed"
        return 601
    fi
    
    # Validate Repair Results
    if ! validate_script "$repair_file"; then
        echo "[SELF-REPAIR-ERROR][CODE:601] Post-repair validation failed"
        return 601
    fi
    
    # Persist Repaired Version
    mkdir -p "$(dirname "$backup_path")"
    cp "$repair_file" "$backup_path" || {
        echo "[SELF-REPAIR-ERROR][CODE:601] Failed to persist repaired version"
        return 601
    }
    chmod +x "$backup_path"
    
    # Generate User Instructions
    cat <<EOF
[SELF-REPAIR-SUCCESS] Self-repair completed! Required actions:
1. Current container continues running (PID $$)
2. On host machine execute:
   docker cp $CONTAINER_ID:$backup_path D:/canvas_envs/00-docker/init-hasura.sh
3. Verify the copied file:
   ls -l D:/canvas_envs/00-docker/init-hasura.sh
4. Restart container:
   docker-compose restart hasura

NOTE: Container will not auto-restart as init.sh is currently executing.
EOF
    
    # Create readiness marker
    touch "/hasura-project/.self-repair-ready"
    echo "[SELF-REPAIR] Readiness marker created"
    return 0
}

# Self-Script Integrity Management
process_self_script() {
    local backup_path="/hasura-project/01-config/hasura/dos2unix/init-hasura.sh"
    
    # Primary Validation
    if validate_script "/hasura-project/init-hasura.sh"; then
        echo "[SELF] Primary init script validated"
        return 0
    fi
    
    # Backup Validation
    if [ -f "$backup_path" ] && validate_script "$backup_path"; then
        echo "[WARNING] Current init.sh is unhealthy but backup is healthy"
        echo "          Backup available at: $backup_path"
        cat <<EOF
[USER-ACTION-REQUIRED] 
To use the healthy backup:
1. On host machine execute:
   docker cp $CONTAINER_ID:$backup_path D:/canvas_envs/00-docker/init-hasura.sh
2. Verify the copied file
3. Restart container:
   docker-compose restart hasura

Container will continue with current instance but may fail.
EOF
        return 0
    fi
    
    # Dual Corruption Scenario
    echo "[CRITICAL] Both primary and backup init.sh are unhealthy"
    
    # Cleanup existing backup if present
    if [ -f "$backup_path" ]; then
        echo "[CLEAN] Removing unhealthy backup"
        rm -f "$backup_path"
    fi
    
    # Execute Self-Repair
    handle_self_repair
    return $?
}

# =============================================================================
# Script Preprocessing System
# =============================================================================

# Script Processing Pipeline
process_scripts() {
    echo "[SCRIPT-PROCESSING] Starting script integrity management"
    
    # Ensure backup directory exists
    local backup_dir="/hasura-project/01-config/hasura/dos2unix"
    mkdir -p "$backup_dir"
    echo "[SCRIPT-PROCESSING] Backup directory: $backup_dir"
    
    # Process Metadata Manager
    ensure_script_integrity \
        "/hasura-project/metadata-manager.sh" \
        "${backup_dir}/metadata-manager.sh" || {
        local status=$?
        echo "[ERROR][CODE:110] Critical failure in metadata-manager.sh (Status: $status)"
        exit 110
    }
    
    # Process Self-Script (for next execution)
    process_self_script || {
        local status=$?
        if [ $status -eq 601 ]; then
            echo "[CRITICAL][CODE:601] Self-repair failed - manual intervention required"
        fi
        # Continue with current instance
    }
    
    echo "[SCRIPT-PROCESSING] All scripts validated/repaired"
}

# Execute Script Processing
process_scripts

# =============================================================================
# Hasura GraphQL Engine Startup
# =============================================================================
echo "[HASURA] Starting GraphQL engine on port 9096..."
graphql-engine serve \
    --server-port 9096 \
    --database-url "$HASURA_GRAPHQL_DATABASE_URL" \
    +RTS -N4 2>&1 | tee /hasura-project/05-logs/hasura/graphql-engine.log &
HGE_PID=$!
echo "[HASURA] Process ID: $HGE_PID"

# =============================================================================
# Hasura Readiness Check
# =============================================================================
echo "[HASURA] Waiting for readiness at $HASURA_GRAPHQL_ENDPOINT..."
for i in {1..90}; do
    if curl -s -f "$HASURA_GRAPHQL_ENDPOINT/healthz" > /dev/null; then
        echo "[HASURA] Ready after ${i} seconds"
        break
    fi
    sleep 1
done

if [ $i -eq 90 ]; then
    echo "[ERROR][CODE:120] Hasura failed to start within 90s"
    exit 120
fi

# =============================================================================
# Metadata Manager Execution
# =============================================================================
echo "[METADATA] Launching metadata manager"

# Prefer repaired version if available
METADATA_MANAGER_SCRIPT="/hasura-project/01-config/hasura/dos2unix/metadata-manager.sh"
if [ ! -x "$METADATA_MANAGER_SCRIPT" ]; then
    METADATA_MANAGER_SCRIPT="/hasura-project/metadata-manager.sh"
fi
echo "[METADATA] Using script: $METADATA_MANAGER_SCRIPT"

# Final pre-execution validation
if validate_script "$METADATA_MANAGER_SCRIPT"; then
    echo "[METADATA] Executing metadata manager"
    bash "$METADATA_MANAGER_SCRIPT"
    METADATA_STATUS=$?
    
    if [ $METADATA_STATUS -ne 0 ]; then
        echo "[ERROR][CODE:$METADATA_STATUS] Metadata processing failed"
        exit $METADATA_STATUS
    fi
else
    echo "[CRITICAL][CODE:130] Final validation failed for metadata manager"
    exit 130
fi

# up health check
echo "[HEALTH] Starting health check server on port 10096..."
python3 -m http.server 10096 --directory /hasura-project &
HEALTH_SERVER_PID=$!
echo "[HEALTH] Health server running with PID: $HEALTH_SERVER_PID"

echo "[INIT] Initialization complete. Access Hasura at $HASURA_GRAPHQL_ENDPOINT"
echo "[INIT] Health check available at http://localhost:10096"
echo "[INIT] Container is now running and awaiting user interaction/process monitoring."

exec tail -f /dev/null
# tail -f /hasura-project/05-logs/hasura/graphql-engine.log
