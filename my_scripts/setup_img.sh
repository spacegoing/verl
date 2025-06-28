pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
pip install gpustat
apt-get install -y tmux
# apt-get install -y \
#         net-tools iproute2 netcat-openbsd \
#         pciutils \
#         infiniband-diags \
#         rdma-core \
#         mstflint \
#         ibverbs-utils \
#         perftest

read -r -d '' ALIAS_BLOCK << 'EOF'

# TMUX aliases
tnew() { tmux new -s "$1"; }
tat() { tmux a -t "$1"; }
tkl() { tmux kill-session -t "$1"; }
cd /root/myCodeLab/host/
EOF

echo -e "\n$ALIAS_BLOCK" >> ~/.bashrc

cat > ~/.tmux.conf << 'EOF'
# --- GENERAL ---
# Set a new prefix key. The default C-b is awkward.
unbind C-b
set -g prefix '^_'
bind-key '^_' send-prefix

# --- NUMBERING & HISTORY ---
# Start window and pane numbering from 1, not 0.
set -g base-index 1
setw -g pane-base-index 1

# Increase the history limit for scrollback.
set -g history-limit 100000

# Keep panes open when the command they were running exits.
set-window-option -g remain-on-exit on

# Persist history to a file to survive reboots.
set -sg history-file ~/.tmux_history

# --- KEYBINDINGS & COPY MODE ---
# Use vi keybindings in copy mode.
set-window-option -g mode-keys vi
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel


# --- PLUGINS ---
# List of plugins managed by tpm.
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-yank'

# Other examples:
# set -g @plugin 'github_username/plugin_name'
# set -g @plugin 'git@github.com/user/plugin'
# set -g @plugin 'git@bitbucket.com/user/plugin'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF


cd /root/myCodeLab/host/verl/
pip install -e .
