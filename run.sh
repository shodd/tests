#!/bin/bash

mkdir -p logs
mkdir -p saved-results

RUN_TESTS=("$@")

should_run() {
  local test="$1"

  if [ -n "$(ls -A results 2>/dev/null)" ]; then
    echo "❌ Cannot run $test: results/ directory is not empty."
    return 1
  fi

  for t in "${RUN_TESTS[@]}"; do
    case "$t" in
      ALL|"$test")
        return 0  # Run this test
        ;;
    esac
  done

  return 1  # Not found in list
}

save_results() {
  mkdir -p "$1"
  for file in results/*; do
    [ -e "$file" ] || continue
    mv "$file" "$1"
  done
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
      alpha=0.5
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
        --simulation-training-runs 1000000 
        --q-learning-alpha $alpha
        --q-learning-gamma $gamma 
        --q-learning-uniform-granularity $granularity 
        --expirations [r1,0] [r2,0] 
        --simulate 1 
        --scheduler-goals MAX  
        --scheduler-histories DH 
        --scheduler-scopes P 
        --unroll-type V"
      
      ./realyst $ARGS > "logs/$logdir/$value.log"

      file=$(ls results | head -n 1)
      extension="${file##*.}"
      mv "results/$file" "saved-results/$resultdir/$value.$extension"
    done
  done
fi

# === SAC ===
if should_run "tank-sac"; then
  TEST_NAME="tank-sac"
  RESULTS_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $RESULTS_DIR

  COMMON_ARGS="
    -l info 
    -b WATERTANK
    -m A 
    --q-learning-alpha 0.25  
    --q-learning-gamma 0.99   
    --expirations [r1,0] [r2,0] 
    --simulate 1 
    --scheduler-goals MAX 
    --unroll-type V
    --q-learning-adaptive-granularity 1 
    --q-learning-uniform-granularity 0.5 
    --simulation-executions 10
  "

  for t in 7 8 9 10 11; do
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 5000 
      --scheduler-histories DH ML 
      --scheduler-scopes NP 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
    
    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 20000 
      --scheduler-histories ML 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 1000000 
      --scheduler-histories HD 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
  done

  for t in 12 14 16 18 20; do
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 1000000 
      --scheduler-histories ML
      --scheduler-scopes P NP
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

  done
fi

# === Tree ===
if should_run "tank-tree"; then
  TEST_NAME="tank-tree"
  RESULTS_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $RESULTS_DIR

  COMMON_ARGS="
    -l info 
    -b WATERTANK
    -m A 
    --q-learning-alpha 0.5 
    --q-learning-gamma 0.95  
    --expirations [r1,3] [r2,5] 
    --simulate 2 
    --scheduler-goals MAX 
    --unroll-type V 
    --q-learning-uniform-granularity 0.5 
    --simulation-executions 10
  "

  for t in 7 8 9 10 11; do
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 5000 
      --scheduler-histories DH ML 
      --scheduler-scopes NP 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
    
    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 20000 
      --scheduler-histories ML 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 1000000 
      --scheduler-histories HD 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
  done
  
  for t in 12 14 16 18 20; do
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs 1000000 
      --scheduler-histories ML HD
      --scheduler-scopes P NP
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

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
      --simulation-training-runs 1000000
      --q-learning-alpha 0.5 
      --q-learning-gamma 0.95 
      --q-learning-uniform-granularity 0.5 
      --expirations [r1,2] [r2,4] 
      --simulate 3 
      --scheduler-goals MAX 
      --scheduler-histories HD
      --scheduler-scopes P
      --unroll-type $unroll_type"
    ./realyst $ARGS > "logs/$TEST_NAME/$unroll_type.log"

    save_results "saved-results/$TEST_NAME/$unroll_type/"
  done
fi

# === unroll-depth ===
if should_run "unroll-depth"; then
  TEST_NAME="unroll-depth"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  for unroll_depth in 1 2 3 4 5; do
    echo "tank with unroll_depth=$unroll_depth"
    ARGS="
      -t 10 
      -l info 
      -b WATERTANK 
      -m A 
      --simulation-training-runs 1000000 
      --q-learning-alpha 0.5 
      --q-learning-gamma 0.95 
      --q-learning-uniform-granularity 0.5 
      --expirations [r1,$unroll_depth] [r2,$unroll_depth] 
      --simulate 3 
      --scheduler-goals MAX 
      --scheduler-histories HD 
      --scheduler-scopes P 
      --unroll-type V"
    ./realyst $ARGS > "logs/$TEST_NAME/$unroll_depth.log"

    save_results "saved-results/$TEST_NAME/$unroll_depth"
  done
fi


if should_run "time-variable"; then
  TEST_NAME="time-variable"

  mkdir -p "logs/$TEST_NAME/with"
  mkdir -p "logs/$TEST_NAME/without"
  mkdir -p "saved-results/$TEST_NAME"


  for t in 7 8 9 10 11 12 14 16 18 20; do
    echo "tank with time-variable at t=$t"

    COMMON_ARGS=" 
      -l trace
      -b WATERTANK
      -m A
      --simulation-training-runs 1000000
      --q-learning-alpha 0.5 
      --q-learning-gamma 0.95 
      --q-learning-uniform-granularity 0.25
      --expirations [r1,0] [r2,0] 
      --simulate 1
      --scheduler-goals MAX
      --scheduler-histories ML
      --scheduler-scopes P
      --unroll-type V
      -t $t
  "

    ./realyst $COMMON_ARGS > "logs/$TEST_NAME/with/$t.log"
    save_results "saved-results/$TEST_NAME/with/"

    ./realyst $COMMON_ARGS --no-time-variable > "logs/$TEST_NAME/without/$t.log"
    save_results "saved-results/$TEST_NAME/without/"
  done
fi

if should_run "intersection"; then
  TEST_NAME="intersection"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"


  for method in R F; do
    echo "tank intersection method=$method"

    COMMON_ARGS=" 
      -l trace
      -b WATERTANK
      -m A
      --simulation-training-runs 1000000
      --q-learning-alpha 0.5 
      --q-learning-gamma 0.95 
      --q-learning-uniform-granularity 0.25
      --expirations [r1,0] [r2,0] 
      --simulate 1
      --scheduler-goals MAX
      --scheduler-histories ML
      --scheduler-scopes P
      --unroll-type V
      -t 20
      --simulation-intersection-method $method
      --no-time-variable
  "

    ./realyst $COMMON_ARGS > "logs/$TEST_NAME/$method.log"
    save_results "saved-results/$TEST_NAME/$method/"

  done
fi


if should_run "sim-execs"; then
  TEST_NAME="sim-execs"
  RESULTS_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $RESULTS_DIR

  COMMON_ARGS="
    -l info 
    -b WATERTANK
    -m A 
    --q-learning-alpha 0.5 
    --q-learning-gamma 0.95 
    --q-learning-uniform-granularity 0.5 
    --expirations [r1,0] [r2,0] 
    --simulate 1 
    --scheduler-goals MAX 
    --unroll-type V
    -t 10 
    --simulation-executions 10
    --scheduler-histories DH 
    --scheduler-scopes NP 
  "

  for exp in 3 4 5 6; do
    FILE="logs/$TEST_NAME/$exp.log"

    exp_val=$((10 ** exp))
    ARGS="
      $COMMON_ARGS 
      --simulation-training-runs $exp_val 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR/$exp
  done
fi

if should_run "rename"; then
  find . -depth -name '*MAXIMIZING*' -exec rename 's/MAXIMIZING/MAX/' '{}' +
  find . -depth -name '*NONPROPHETIC*' -exec rename 's/NONPROPHETIC/NP/' '{}' +
  find . -depth -name '*PROPHETIC*' -exec rename 's/PROPHETIC/SP/' '{}' +
  find . -depth -name '*MEMORYLESS*' -exec rename 's/MEMORYLESS/ML/' '{}' +
  find . -depth -name '*DISCRETE_HISTORY*' -exec rename 's/DISCRETE_HISTORY/DH/' '{}' +
  find . -depth -name '*HISTORY_DEPENDENT*' -exec rename 's/HISTORY_DEPENDENT/HD/' '{}' +
fi