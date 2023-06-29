# lazy-zsh-hf
lazy-zsh-hf is a HuggingFace powered utility for Zsh that helps you write and modify console commands using natural language.
inspired by https://github.com/not-poma/lazyshell

# Setup
Copy lazy-zsh-hf.zsh to ~/.oh-my-zsh/custom/plugins/lazy-zsh-hf/lazy-zsh-hf.zsh
Edit ~/.zshenv and add 
export HUGGING_FACE_HUB_TOKEN="h......."
Get your TOKEN here https://huggingface.co/settings/tokens

# Use
Invoke the completion with ALT+G hotkey; you still have to manually press enter to execute the suggested command.
It also can use HuggingFace to explain what the current command does. Invoke the explanation with ALT+E hotkey.
