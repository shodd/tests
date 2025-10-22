#!/bin/bash

mkdir -p logs
mkdir -p results
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
    "gamma|0.25 0.50 0.75 0.90 0.95 1.00"
    "granularity|0.10 0.25 0.50 1.00 2.00 3.00"
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
      gamma=1
      granularity=0.5

      # Override the one being tested
      case $param in
        alpha) alpha=$value ;;
        gamma) gamma=$value ;;
        granularity) granularity=$value ;;
      esac

      ARGS="
        -t 10 
        -l info 
        -b EVALUATION_THESIS_FELIX 
        -m A 
        --simulation-training-runs 5000 
        --q-learning-alpha $alpha
        --q-learning-gamma $gamma 
        --discretization-uniform-granularity $granularity 
        --expirations [r1,0] [r2,0] 
        --simulate 1 
        --scheduler-goals MAX  
        --scheduler-histories ML 
        --scheduler-scopes NP 
        --unroll-type V
        --simulation-executions 25
        "
      
      ./realyst $ARGS >> "logs/$logdir/$value.log"

      file=$(ls results | head -n 1)
      extension="${file##*.}"
      mv "results/$file" "saved-results/$resultdir/$value.$extension"
    done
  done
fi

# === q-learning prophetic ===
if should_run "granularity-prophetic"; then
  TEST_NAME="granularity-prophetic"
  BASE_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $BASE_DIR

  for granularity in {0.1,0.5,1.0}; do
    for episodes in {1000,10000,100000,1000000,10000000}; do
      echo "tank prophetic with granularity=$granularity and episodes=$episodes"

      ARGS="
        -t 8   
        -l info 
        -b EVALUATION_THESIS_FELIX 
        -m A 
        --simulation-training-runs $episodes 
        --q-learning-alpha 0.1 
        --q-learning-gamma 1 
        --discretization-uniform-granularity $granularity 
        --expirations [r1,0] [r2,0] 
        --simulate 1 
        --scheduler-goals MAX  
        --scheduler-histories HD 
        --scheduler-scopes P 
        --unroll-type V
        --simulation-executions 1
        --simulation-intersection-method R
        --simulation-util-plot-first-decision-in-EVALUATION_THESIS_FELIX
      "
      ./realyst $ARGS >> "logs/$TEST_NAME/g${granularity}_e${episodes}.log"
      file=$(ls results | head -n 1)
      extension="${file##*.}"
      mv "results/$file" "$BASE_DIR/g${granularity}_e${episodes}.$extension"
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
    -b EVALUATION_THESIS_FELIX
    -m A 
    --q-learning-alpha 0.1  
    --q-learning-gamma 1.0   
    --expirations [r1,0] [r2,0] 
    --simulate 1 
    --scheduler-goals MAX 
    --unroll-type V
    --simulation-executions 25
    --simulation-intersection-method R
  "

  for t in 7 8 9 10 11; do
    echo "tank sac with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 1.0 
      --simulation-training-runs 5000 
      --scheduler-histories DH ML 
      --scheduler-scopes NP 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
    
    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 20000 
      --scheduler-histories ML 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 1000000 
      --scheduler-histories HD 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
  done

  for t in 12 14 16 18 20; do
    echo "tank sac with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 1000000 
      --scheduler-histories ML
      --scheduler-scopes P NP
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

  done
fi

if should_run "tank-sac-init"; then
  TEST_NAME="tank-sac-init"
  RESULTS_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $RESULTS_DIR

  COMMON_ARGS="
    -l info 
    -b EVALUATION_THESIS_FELIX
    -m D  
    --q-learning-alpha 0.1  
    --q-learning-gamma 1.0   
    --expirations [r1,0] [r2,0] 
    --simulate 1 
    --scheduler-goals MAX 
    --unroll-type V
    --simulation-executions 25
    --simulation-intersection-method R
  "

  for t in 7 8 9 10 11; do
    echo "tank sac with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 1.0 
      --simulation-training-runs 5000 
      --scheduler-histories DH ML 
      --scheduler-scopes NP 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
    
    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 20000 
      --scheduler-histories ML 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 1000000 
      --scheduler-histories HD 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
  done

  for t in 12 14 16 18 20; do
    echo "tank sac with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5  
      --simulation-training-runs 1000000 
      --scheduler-histories ML
      --scheduler-scopes P NP
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

  done
fi

if should_run "tank-sac-full-power"; then
  TEST_NAME="tank-sac-full-power"
  RESULTS_DIR="saved-results/$TEST_NAME"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p $RESULTS_DIR

  for t in 7 8 9 10 11 12 14 16 18 20; do
    echo "tank sac full power with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      -l info 
      -b EVALUATION_THESIS_FELIX
      -m A 
      --q-learning-alpha 0.1  
      --q-learning-gamma 1.0   
      --expirations [r1,0] [r2,0] 
      --simulate 1 
      --scheduler-goals MAX 
      --unroll-type V
      --simulation-executions 25
      --simulation-intersection-method R 
      --discretization-uniform-granularity 0.5 
      --simulation-training-runs 10000000
      --scheduler-histories HD
      --scheduler-scopes P 
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
    -b EVALUATION_THESIS_FELIX
    -m A 
    --q-learning-alpha 0.1 
    --q-learning-gamma 1.0   
    --expirations [r1,0] [r2,0] 
    --simulate 2 
    --scheduler-goals MAX 
    --unroll-type V 
    --simulation-executions 25
    --simulation-intersection-method R
  "

  for t in 7 8 9 10 11; do
    echo "tank tree with t=$t"
    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 1.0 
      --simulation-training-runs 5000 
      --scheduler-histories DH ML 
      --scheduler-scopes NP 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
    
    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 1.0 
      --simulation-training-runs 20000 
      --scheduler-histories ML 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5
      --simulation-training-runs 1000000 
      --scheduler-histories HD 
      --scheduler-scopes P 
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR
  done
  
  for t in 12 14 16 18 20; do
    echo "tank tree with t=$t"

    FILE="logs/$TEST_NAME/$t.log"

    ARGS="
      $COMMON_ARGS 
      --discretization-uniform-granularity 0.5
      --simulation-training-runs 1000000 
      --scheduler-histories ML 
      --scheduler-scopes P NP
      -t $t 
    "
    ./realyst $ARGS >> $FILE
    save_results $RESULTS_DIR

  done
fi

if should_run "synthetic-nondet"; then
  TEST_NAME="synthetic-nondet"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  echo "test $TEST_NAME"
    ARGS="
      -t 6  
      -l info 
      -b EVALUATION_THESIS_FELIX
      -m B 
      --simulation-training-runs 100000  
      --q-learning-alpha 0.02
      --q-learning-gamma 1 
      --discretization-uniform-granularity 0.5 
      --expirations [r1,0] [r2,0] 
      --simulate 1 
      --scheduler-goals MAX 
      --scheduler-histories ML 
      --scheduler-scopes NP 
      --simulation-executions 25 
      --unroll-type V"
    ./realyst $ARGS > "logs/$TEST_NAME/$nondet.log"

    save_results "saved-results/$TEST_NAME/$nondet"
fi

if should_run "synthetic-multi-trans"; then
  TEST_NAME="synthetic-multi-trans"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  echo "test $TEST_NAME"
    ARGS="
      -t 6  
      -l info 
      -b EVALUATION_THESIS_FELIX
      -m C 
      --simulation-training-runs 5000  
      --q-learning-alpha 0.1 
      --q-learning-gamma 1 
      --discretization-uniform-granularity 0.5 
      --expirations [r1,0] [r2,0] 
      --simulate 3 
      --scheduler-goals MAX 
      --scheduler-histories ML 
      --scheduler-scopes NP 
      --simulation-executions 5  
      --unroll-type V"
    ./realyst $ARGS > "logs/$TEST_NAME/$nondet.log"

    save_results "saved-results/$TEST_NAME/$nondet"
fi

# === unroll-depth ===
if should_run "jump-bound"; then
  TEST_NAME="jump-bound"

  mkdir -p "logs/$TEST_NAME"
  mkdir -p "saved-results/$TEST_NAME"

  for unroll_depth in 0 1 2 3 4 5; do
    echo "test $TEST_NAME with jmp=$unroll_depth"
    ARGS="
      -t 6  
      -l info 
      -b EVALUATION_THESIS_FELIX 
      -m A 
      --simulation-training-runs 1  
      --q-learning-alpha 0.1 
      --q-learning-gamma 1 
      --discretization-uniform-granularity 0.5 
      --expirations [r1,$unroll_depth] [r2,$unroll_depth] 
      --simulate 2 
      --scheduler-goals MAX 
      --scheduler-histories HD 
      --scheduler-scopes P 
      --unroll-type $((unroll_depth > 0 ? D : V))"
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
      -l info
      -b EVALUATION_THESIS_FELIX
      -m A
      --simulation-training-runs 1000000
      --q-learning-alpha 0.1 
      --q-learning-gamma 1 
      --discretization-uniform-granularity 0.5
      --expirations [r1,0] [r2,0] 
      --simulate 1
      --scheduler-goals MAX
      --scheduler-histories HD
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
      -l info
      -b EVALUATION_THESIS_FELIX
      -m A
      --simulation-training-runs 1000000
      --q-learning-alpha 0.1 
      --q-learning-gamma 1  
      --discretization-uniform-granularity 0.25
      --expirations [r1,0] [r2,0] 
      --simulate 1
      --scheduler-goals MAX
      --scheduler-histories ML
      --scheduler-scopes P
      --unroll-type V
      -t 20
      --simulation-intersection-method $method
      "

    ./realyst $COMMON_ARGS > "logs/$TEST_NAME/$method.log"
    save_results "saved-results/$TEST_NAME/$method/"

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