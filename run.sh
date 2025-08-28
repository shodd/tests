#!/bin/bash

mkdir -p saved-results

# Get the tests to run (convert ALL to wildcard match)
RUN_TESTS=("$@")
should_run() {
  local test="$1"

  if [ -n "$(ls -A results 2>/dev/null)" ]; then
    echo "❌ Cannot run $test: results/ directory is not empty."
    return 1
  fi

  [[ " ${RUN_TESTS[@]} " =~ " ALL " || " ${RUN_TESTS[@]} " =~ " $test " ]]
}

# === q-learning ===
if should_run "q-learning"; then
  TEST_NAME="q-learning"

  # Format: param_name|space-separated-values
  experiments=(
    "alpha|0.05 0.10 0.15 0.25 0.50 0.75"
    "gamma|0.25 0.50 0.75 0.90 0.95 0.99"
    "granularity|0.1 0.25 0.5 1.0 2.0 3.0"
  )

  for experiment in "${experiments[@]}"; do
    IFS='|' read -r param values <<< "$experiment"

    logdir="$TEST_NAME/$param"
    resultdir="$TEST_NAME/$param"

    mkdir -p "logs/$logdir"
    mkdir -p "saved-results/$resultdir"

    for value in $values; do
      echo "tank with $param=$value"

      # Default values
      alpha=0.1
      gamma=0.99
      granularity=0.25

      # Override the one being tested
      case $param in
        alpha) alpha=$value ;;
        gamma) gamma=$value ;;
        granularity) granularity=$value ;;
      esac

      ARGS="
        -t 10 
        -l info 
        -b WATERTANK 
        -m A 
        --simulation-runs 1000000
        --simulation-training-runs 1000000 
        -d 256 
        --q-learning-alpha $alpha
        --q-learning-gamma $gamma 
        --q-learning-uniform-granularity $granularity 
        --expirations [r1,0] [r2,0] 
        --simulate 1 
        --scheduler-goals MAX  
        --scheduler-histories ML 
        --scheduler-scopes P 
        --unroll-type V"
      
      ./realyst $ARGS > "logs/$logdir/$value.log"

      file=$(ls results | head -n 1)
      extension="${file##*.}"
      mv "results/$file" "saved-results/$resultdir/$value.$extension"
    done
  done
fi

# === tank-7-11 ===
if should_run "tank-7-11"; then
  TEST_NAME="tank-7-11"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  for t in 7 8 9 10 11; do
    echo "tank with t=$t"
    ARGS="
      -t $t 
      -l info 
      -b WATERTANK 
      -m A 
      --simulation-runs 1000000
      --simulation-training-runs 1000000 
      -d 256 
      --q-learning-alpha 0.1 
      --q-learning-gamma 0.99 
      --q-learning-uniform-granularity 0.25 
      --expirations [r1,2] [r2,4] 
      --simulate 3 
      --scheduler-goals MAX 
      --scheduler-histories ML DH HD
      --scheduler-scopes P NP
      --unroll-type V"
    ./realyst $ARGS > "logs/$TEST_NAME/$t.log"

    for file in results/*; do
      [ -e "$file" ] || continue
      mv "$file" "saved-results/$TEST_NAME/"
    done
  done
fi

# === unroll-type ===
if should_run "unroll-type"; then
  TEST_NAME="unroll-type"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  for unroll_type in V K D; do
    echo "tank with unroll_type=$unroll_type"
    ARGS="
      -t 10 
      -l info 
      -b WATERTANK 
      -m A 
      --simulation-runs 1000000
      --simulation-training-runs 1000000 
      -d 256 
      --q-learning-alpha 0.1 
      --q-learning-gamma 0.99 
      --q-learning-uniform-granularity 0.25 
      --expirations [r1,2] [r2,4] 
      --simulate 3 
      --scheduler-goals MAX 
      --scheduler-histories ML
      --scheduler-scopes P
      --unroll-type $unroll_type"
    ./realyst $ARGS > "logs/$TEST_NAME/$unroll_type.log"

    mkdir -p "saved-results/$TEST_NAME/$unroll_type"
    for file in results/*; do
      [ -e "$file" ] || continue
      mv "$file" "saved-results/$TEST_NAME/$unroll_type/"
    done
  done
fi

# === unroll-depth ===
if should_run "unroll-depth"; then
  TEST_NAME="unroll-depth-sac"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  for unroll_depth in 1 2 3 4 5; do
    echo "tank with unroll_depth=$unroll_depth"
    ARGS="
      -t 10 
      -l info 
      -b WATERTANK 
      -m A 
      --simulation-runs 1000000
      --simulation-training-runs 1000000 
      -d 256 
      --q-learning-alpha 0.1 
      --q-learning-gamma 0.99 
      --q-learning-uniform-granularity 0.25 
      --expirations [r1,$unroll_depth] [r2,$unroll_depth] 
      --simulate 1 
      --scheduler-goals MAX 
      --scheduler-histories ML
      --scheduler-scopes P
      --unroll-type V"
    ./realyst $ARGS > "logs/$TEST_NAME/$unroll_depth.log"

    mkdir -p "saved-results/$TEST_NAME/$unroll_depth"
    for file in results/*; do
      [ -e "$file" ] || continue
      mv "$file" "saved-results/$TEST_NAME/$unroll_depth/"
    done
  done
fi

# === tank-12-20 ===
if should_run "tank-12-20"; then
  TEST_NAME="tank-12-20"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  run_tank_12_20_variant() {
    local mode="$1"
    local expirations="$2"
    local simulate="$3"

    mkdir -p "logs/$TEST_NAME/$mode"
    mkdir -p "saved-results/$TEST_NAME/$mode"

    for t in 12 14 16 18 20; do
      echo "tank with t=$t on $mode"
      ARGS="
        -t $t 
        -l info 
        -b WATERTANK 
        -m A 
        --simulation-runs 1000000
        --simulation-training-runs 1000000 
        -d 256 
        --q-learning-alpha 0.1 
        --q-learning-gamma 0.99 
        --q-learning-uniform-granularity 0.25 
        --expirations $expirations 
        --simulate $simulate 
        --scheduler-goals MAX 
        --scheduler-histories ML 
        --scheduler-scopes P NP
        --unroll-type V"
      ./realyst $ARGS > "logs/$TEST_NAME/$mode/$t.log"

      for file in results/*; do
        [ -e "$file" ] || continue
        mv "$file" "saved-results/$TEST_NAME/$mode/"
      done
    done
  }

  run_tank_12_20_variant "sac"  "[r1,0] [r2,0]" 1
  run_tank_12_20_variant "tree" "[r1,2] [r2,4]" 2
fi


