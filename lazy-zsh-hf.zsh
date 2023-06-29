#!/usr/bin/env zsh

__lzsh_get_distribution_name() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "$(sw_vers -productName) $(sw_vers -productVersion)" 2>/dev/null
  else
    echo "$(cat /etc/*-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
  fi
}

__lzsh_get_os_prompt_injection() {
  local os=$(__lzsh_get_distribution_name)
  if [[ -n "$os" ]]; then
    echo " for $os"
  else
    echo ""
  fi
}

__lzsh_preflight_check() {
  emulate -L zsh
  if [ -z "$HUGGING_FACE_HUB_TOKEN" ]; then
    echo ""
    echo "Error: HUGGING_FACE_HUB_TOKEN is not set"
    echo "Set your Hugging Face Hub token by running:"
    echo "export HUGGING_FACE_HUB_TOKEN=<your Hugging Face Hub token>"
    zle reset-prompt
    return 1
  fi

  if ! command -v jq &> /dev/null; then
    echo ""
    echo "Error: jq is not installed"
    zle reset-prompt
    return 1
  fi

  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo ""
    echo "Error: curl or wget is not installed"
    zle reset-prompt
    return 1
  fi
}

__lzsh_llm_api_call() {
  emulate -L zsh
  # calls the llm API, shows a nice spinner while it's running 
  # called without a subshell to stay in the widget context, returns the answer in $generated_text variable
  local intro="$1"
  local prompt="$2"
  local progress_text="$3"

  local response_file=$(mktemp)

  local escaped_prompt=$(echo "$prompt" | jq -R -s '.')
  local escaped_intro=$(echo "$intro" | jq -R -s '.')
  local data='{"inputs":[{"role": "system", "content": '"$escaped_intro"'},{"role": "user", "content": '"$escaped_prompt"'}],"model":"gpt-3.5-turbo","max_tokens":256,"temperature":0}'

  # Read the response from file
  # Todo: avoid using temp files
  set +m
  if command -v curl &> /dev/null; then
    { curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $HUGGING_FACE_HUB_TOKEN" -d "$data" https://api-inference.huggingface.co/models/openai/gpt > "$response_file" } &>/dev/null &
  else
    { wget -qO- --header="Content-Type: application/json" --header="Authorization: Bearer $HUGGING_FACE_HUB_TOKEN" --post-data="$data" https://api-inference.huggingface.co/models/openai/gpt > "$response_file" } &>/dev/null &
  fi
  local pid=$!

  # Display a spinner while the API request is running in the background
  local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  while true; do
    for i in "${spinner[@]}"; do
      if ! kill -0 $pid 2> /dev/null; then
        break 2
      fi

      zle -R "$i $progress_text"
      sleep 0.1
    done
  done

  wait $pid
  if [ $? -ne 0 ]; then
    zle -M "Error: API request failed"
    return 1
  fi

  local response=$(cat "$response_file")
  # explicit rm invocation to avoid user shell overrides
  command rm "$response_file"

  local error=$(echo -E $response | jq -r '.error')
  generated_text=$(echo -E $response | jq -r '.generated_text' | tr '\n' '\r' | sed -e $'s/^[ \r`]*//; s/[ \r`]*$//' | tr '\r' '\n')

  if [ $? -ne 0 ]; then
    zle -
