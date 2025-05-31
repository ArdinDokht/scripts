#!/bin/bash

# --- Settings ---
PROMETHEUS_URL="http://localhost:9090" # Enter your Prometheus server URL
TIME_WINDOW="24h"                     # Time window for data analysis (e.g., 1h, 1d)
CPU_REQUEST_PERCENTILE="0.50"         # Percentile for CPU request suggestion (average)
CPU_LIMIT_PERCENTILE="0.95"           # Percentile for CPU limit suggestion (peak)
MEM_REQUEST_PERCENTILE="0.50"         # Percentile for Memory request suggestion
MEM_LIMIT_PERCENTILE="0.95"           # Percentile for Memory limit suggestion
CPU_LIMIT_BUFFER_FACTOR="1.2"         # Buffer factor for CPU limit (e.g., 20% more)
MEM_LIMIT_BUFFER_FACTOR="1.2"         # Buffer factor for Memory limit

# --- Check and install jq ---
check_and_install_jq() {
  if command -v jq &> /dev/null; then
    echo "jq is already installed."
    return 0
  fi

  echo "jq not found. Attempting to install..."
  # Check package manager
  if command -v apt-get &> /dev/null; then
    echo "Using apt to install jq..."
    sudo apt-get update
    sudo apt-get install -y jq
  elif command -v yum &> /dev/null; then
    echo "Using yum to install jq..."
    sudo yum install -y jq
  elif command -v dnf &> /dev/null; then
    echo "Using dnf to install jq..."
    sudo dnf install -y jq
  elif command -v pacman &> /dev/null; then
    echo "Using pacman to install jq..."
    sudo pacman -Syu --noconfirm jq
  elif command -v zypper &> /dev/null; then
    echo "Using zypper to install jq..."
    sudo zypper install -y jq
  else
    echo "Could not find a known package manager. Please install jq manually."
    return 1
  fi

  if command -v jq &> /dev/null; then
    echo "jq installed successfully."
  else
    echo "Error installing jq. Please install it manually."
    return 1
  fi
  return 0
}

# Execute jq check and installation
if ! check_and_install_jq; then
  exit 1
fi

# --- Functions ---

# Function to execute PromQL query and get result as JSON
query_prometheus() {
  local query="$1"
  # Use -f to fail silently on server errors and --connect-timeout
  curl -s -f --connect-timeout 5 -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${query}" | jq .
}

# Function to execute PromQL query for a time range and get result
query_prometheus_range() {
  local query_metric="$1"
  local container_name_filter="$2"
  local duration="$3" # e.g., 5m, 1h, 1d

  local step="60s" # Default
  if [[ "$duration" == *"h"* || "$duration" == *"d"* ]]; then
    step="5m"
  fi
  if [[ "$duration" == *"d"* ]]; then
    local days
    days=$(echo "$duration" | sed 's/d//')
    if [ "$days" -gt 1 ]; then
        step="15m"
    fi
    if [ "$days" -gt 7 ]; then
        step="1h" # For very long ranges, increase the step
    fi
  fi

  local end_time
  end_time=$(date +%s)
  # Calculate start_time using date -d for better handling of time units
  local start_time_str
  case "$duration" in
    *m) start_time_str="${duration%m} minutes ago" ;;
    *h) start_time_str="${duration%h} hours ago" ;;
    *d) start_time_str="${duration%d} days ago" ;;
    *) echo "Invalid format for duration: $duration"; return 1 ;;
  esac
  local start_time
  start_time=$(date -d "$start_time_str" +%s)


  # For CPU, we use rate
  # Ensure the container name is correctly included in the query.
  # If the container name contains special characters, it might need escaping.
  # This query usually works for Docker containers monitored by cAdvisor.
  # For Kubernetes, the filter might be container="$container_name_filter" or pod="$pod_name".
  # It's best to find a label that uniquely identifies your container.
  # Example: {container_name="$container_name_filter"} or {name="$container_name_filter"} or {container="$container_name_filter"}
  # Here, `name` is used, which matches the cAdvisor standard.
  local query
  if [[ "$query_metric" == "container_cpu_usage_seconds_total" ]]; then
    # Rate for CPU should be calculated over a small interval (e.g., 5m) to show fluctuations
    query="sum(rate(${query_metric}{name=\"${container_name_filter}\"}[5m])) by (name, id)"
  else
    query="${query_metric}{name=\"${container_name_filter}\"}"
  fi

  # echo "DEBUG: Range Query: ${query}"
  # echo "DEBUG: Start: $(date -u -d @$start_time +'%Y-%m-%dT%H:%M:%SZ'), End: $(date -u -d @$end_time +'%Y-%m-%dT%H:%M:%SZ'), Step: ${step}"

  curl -s -f --connect-timeout 15 -G "${PROMETHEUS_URL}/api/v1/query_range" \
    --data-urlencode "query=${query}" \
    --data-urlencode "start=${start_time}" \
    --data-urlencode "end=${end_time}" \
    --data-urlencode "step=${step}" | jq .
}

# Function to calculate percentile from a list of numbers
calculate_percentile() {
  local percentile_float=$1 # e.g., 0.95
  shift
  local values=("$@")
  if [ ${#values[@]} -eq 0 ]; then
    echo "0"
    return
  fi

  # Convert float to integer for datamash (e.g., 0.95 -> 95)
  local percentile_int
  percentile_int=$(echo "$percentile_float * 100" | bc | awk '{printf "%d", $1}')

  if command -v datamash &> /dev/null; then
    # datamash needs input from stdin, one value per line
    printf "%s\n" "${values[@]}" | datamash -t',' perc "$percentile_int" 1 2>/dev/null || echo "0" # If error or no value, return 0
  else
    # echo "Warning: datamash not found. Using basic percentile calculation (less accurate)." >&2
    local count=${#values[@]}
    # Calculate index based on nearest-rank method (simplified)
    # (N-1) * p
    local index_float
    index_float=$(echo "($count - 1) * $percentile_float" | bc -l)
    local index_int
    index_int=$(printf "%.0f" "$index_float") # Round to nearest integer

    # Sort values and select the value at the calculated index
    local sorted_values
    sorted_values=($(printf "%s\n" "${values[@]}" | sort -n))
    echo "${sorted_values[$index_int]:-0}" # If index is out of bounds, return 0
  fi
}

# Function to convert bytes to megabytes
bytes_to_mb() {
  if ! [[ "$1" =~ ^[0-9.]+$ ]]; then echo "0.00"; return; fi # Check for numeric input
  echo "$1 / (1024*1024)" | bc -l | awk '{printf "%.2f", $1}'
}

# --- Main Logic ---

echo "Fetching list of containers..."
# Query to get names of recently seen containers.
# This query looks for containers with the `name` label.
# For Kubernetes, you might want to use the `container` label and filter specific pods.
# Example for Kubernetes: 'group by (container, pod, namespace) (container_last_seen{container!="", pod!="", namespace!="kube-system"})'
# Here we operate based on `name` which cAdvisor typically uses for Docker containers.
# If you use Kubernetes, you'll need to adjust this query to match your metrics structure.
# container_names_json=$(query_prometheus 'group by (name) (container_last_seen{name!=""})')
# Filter out some common system or temporary Docker containers (this list might need to be extended)
container_names_json=$(query_prometheus 'group by (name) (container_last_seen{name!="", name!~".*kube-system.*", name!~".*POD", name!~"container_memory_.*"})')


if [ -z "$container_names_json" ] || ! echo "$container_names_json" | jq -e '.status == "success"' >/dev/null || ! echo "$container_names_json" | jq -e '.data.result | length > 0' >/dev/null; then
  echo "Error fetching container list or no containers found."
  echo "Raw Prometheus output:"
  echo "$container_names_json"
  exit 1
fi

# Use process substitution to correctly read names that might contain spaces
while IFS= read -r container_name; do
  if [ -z "$container_name" ]; then
    continue
  fi

  # Remove potential quotes from container name if jq added them
  container_name_clean=$(echo "$container_name" | sed 's/"//g')

  echo "--------------------------------------------------"
  echo "Analyzing container: $container_name_clean"
  echo "Time window: $TIME_WINDOW"
  echo "--------------------------------------------------"

  # --- CPU Analysis ---
  echo "  Fetching CPU data..."
  cpu_data_json=$(query_prometheus_range "container_cpu_usage_seconds_total" "$container_name_clean" "$TIME_WINDOW")

  local cpu_values=()
  if ! echo "$cpu_data_json" | jq -e '.status == "success"' >/dev/null || ! echo "$cpu_data_json" | jq -e '.data.result[0].values | length > 0' >/dev/null; then
    echo "  Error: CPU data not found or no data for $container_name_clean."
    # echo "  Raw CPU output: $cpu_data_json" # For debugging
  else
    # Extract CPU usage values (these are rates, i.e., number of cores consumed)
    # Filter out null values that might appear if a scrape was missed
    mapfile -t cpu_values < <(echo "$cpu_data_json" | jq -r '.data.result[0].values[][1] // "0"' | grep -v null)
  fi

  if [ ${#cpu_values[@]} -gt 0 ]; then
    cpu_request_val=$(calculate_percentile "$CPU_REQUEST_PERCENTILE" "${cpu_values[@]}")
    cpu_limit_val_raw=$(calculate_percentile "$CPU_LIMIT_PERCENTILE" "${cpu_values[@]}")
    cpu_limit_val=$(echo "scale=3; $cpu_limit_val_raw * $CPU_LIMIT_BUFFER_FACTOR / 1" | bc -l) # Ensure scale for bc

    # If values are too small, consider a minimum (e.g., 0.1 cores)
    min_cpu_request="0.1"
    min_cpu_limit="0.2"
    is_less_cpu_request=$(echo "$cpu_request_val < $min_cpu_request" | bc -l)
    is_less_cpu_limit=$(echo "$cpu_limit_val < $min_cpu_limit" | bc -l)

    if [ "$is_less_cpu_request" -eq 1 ]; then cpu_request_val=$min_cpu_request; fi
    if [ "$is_less_cpu_limit" -eq 1 ]; then cpu_limit_val=$min_cpu_limit; fi


    printf "  CPU Suggestion:\n"
    printf "    Request: %.3f cores\n" "$cpu_request_val"
    printf "    Limit:   %.3f cores (Raw max (P%.0f): %.3f, Buffered)\n" "$cpu_limit_val" "$(echo "$CPU_LIMIT_PERCENTILE*100" | bc)" "$cpu_limit_val_raw"
  else
    echo "  Not enough data to suggest CPU resources."
  fi

  # --- Memory Analysis ---
  echo "  Fetching memory data (working set)..."
  mem_data_json=$(query_prometheus_range "container_memory_working_set_bytes" "$container_name_clean" "$TIME_WINDOW")

  local mem_values=()
  if ! echo "$mem_data_json" | jq -e '.status == "success"' >/dev/null || ! echo "$mem_data_json" | jq -e '.data.result[0].values | length > 0' >/dev/null; then
    echo "  Error: Memory data (working set) not found or no data for $container_name_clean."
    # echo "  Raw memory output: $mem_data_json" # For debugging
  else
    # Extract memory usage values in bytes
    # Filter out null values
    mapfile -t mem_values < <(echo "$mem_data_json" | jq -r '.data.result[0].values[][1] // "0"' | grep -v null)
  fi

  if [ ${#mem_values[@]} -gt 0 ]; then
    mem_request_val_bytes=$(calculate_percentile "$MEM_REQUEST_PERCENTILE" "${mem_values[@]}")
    mem_limit_val_raw_bytes=$(calculate_percentile "$MEM_LIMIT_PERCENTILE" "${mem_values[@]}")
    mem_limit_val_bytes=$(echo "scale=0; $mem_limit_val_raw_bytes * $MEM_LIMIT_BUFFER_FACTOR / 1" | bc) # Round to whole byte

    # Minimum suggested memory (e.g., 64 MiB for request, 128 MiB for limit)
    min_mem_request_bytes=$((64 * 1024 * 1024))
    min_mem_limit_bytes=$((128 * 1024 * 1024))

    is_less_mem_request=$(echo "$mem_request_val_bytes < $min_mem_request_bytes" | bc -l)
    is_less_mem_limit=$(echo "$mem_limit_val_bytes < $min_mem_limit_bytes" | bc -l)

    if [ "$is_less_mem_request" -eq 1 ]; then mem_request_val_bytes=$min_mem_request_bytes; fi
    if [ "$is_less_mem_limit" -eq 1 ]; then mem_limit_val_bytes=$min_mem_limit_bytes; fi


    mem_request_mb=$(bytes_to_mb "$mem_request_val_bytes")
    mem_limit_mb=$(bytes_to_mb "$mem_limit_val_bytes")
    mem_limit_raw_mb=$(bytes_to_mb "$mem_limit_val_raw_bytes")

    printf "  Memory Suggestion:\n"
    printf "    Request: %.2f MiB\n" "$mem_request_mb"
    printf "    Limit:   %.2f MiB (Raw max (P%.0f): %.2f MiB, Buffered)\n" "$mem_limit_mb" "$(echo "$MEM_LIMIT_PERCENTILE*100" | bc)" "$mem_limit_raw_mb"
  else
    echo "  Not enough data to suggest memory resources."
  fi

done < <(echo "$container_names_json" | jq -r '.data.result[].metric.name')

echo "--------------------------------------------------"
echo "Analysis complete."
