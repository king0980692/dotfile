#!/bin/bash

# 臨時文件來追蹤當前 pane 索引和 session
PANE_STATE_FILE="/tmp/tmux_fzf_pane_state_$$"
NEW_SESSION_FILE="/tmp/tmux_fzf_new_session_$$"
echo "||0|0" > "$PANE_STATE_FILE"  # 格式: session_name|window.pane|index|count

# 清理函數
cleanup() {
    rm -f "$PANE_STATE_FILE" "$NEW_SESSION_FILE"
}
trap cleanup EXIT


# 2. 管道串接並使用 fzf
CURRENT_SESSION=$(tmux display-message -p '#{session_name}')
SELECTED_SESSION=$(
  tmux list-sessions -F '#{session_name}' | \
    grep -v "^popup$" | \
	grep -v "^$CURRENT_SESSION$" | \
    fzf --preview '
        # 讀取狀態文件
        STATE=$(cat '"$PANE_STATE_FILE"' 2>/dev/null || echo "||0|0")
        PREV_SESSION=$(echo "$STATE" | cut -d"|" -f1)
        PANE_IDX=$(echo "$STATE" | cut -d"|" -f3)

        # 如果切換了 session，重置索引
        if [ -n "$PREV_SESSION" ] && [ "$PREV_SESSION" != "{}" ]; then
            PANE_IDX=0
        fi

        # 獲取該 session 當前活躍 window 的 panes
        CURRENT_WINDOW=$(tmux display-message -t {} -p "#{window_index}" 2>/dev/null)
        PANES=($(tmux list-panes -t {}:$CURRENT_WINDOW -F "#{window_index}.#{pane_index}" 2>/dev/null))
        PANE_COUNT=${#PANES[@]}

        if [ $PANE_COUNT -eq 0 ]; then
            echo "No panes available in session: {}"
            exit 0
        fi

        # 確保索引在範圍內（循環）
        PANE_IDX=$((PANE_IDX % PANE_COUNT))
        if [ $PANE_IDX -lt 0 ]; then
            PANE_IDX=$((PANE_COUNT + PANE_IDX))
        fi

        # 獲取目標 pane
        TARGET_PANE=${PANES[$PANE_IDX]}

        # 更新狀態文件
        echo "{}|$TARGET_PANE|$PANE_IDX|$PANE_COUNT" > '"$PANE_STATE_FILE"'

        # 顯示 pane 內容
        tmux capture-pane -e -t {}:$TARGET_PANE -p 2>/dev/null || echo "Cannot capture pane: $TARGET_PANE"
    ' \
    --bind "up:up+execute-silent(sleep 0.05)+transform-preview-label:
        STATE=\$(cat $PANE_STATE_FILE 2>/dev/null || echo '|||0|0')
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)

        if [ -z \"\$SESSION\" ] || [ \"\$SESSION\" = \"{}\" ]; then
            SESSION=\"{}\"
        fi

        if [ -z \"\$COUNT\" ] || [ \"\$COUNT\" = \"0\" ]; then
            echo \" Session: \$SESSION \"
        else
            echo \" Session: \$SESSION | Pane: \$PANE | [\$((IDX + 1))/\$COUNT] \"
        fi
    " \
    --bind "down:down+execute-silent(sleep 0.05)+transform-preview-label:
        STATE=\$(cat $PANE_STATE_FILE 2>/dev/null || echo '|||0|0')
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)

        if [ -z \"\$SESSION\" ] || [ \"\$SESSION\" = \"{}\" ]; then
            SESSION=\"{}\"
        fi

        if [ -z \"\$COUNT\" ] || [ \"\$COUNT\" = \"0\" ]; then
            echo \" Session: \$SESSION \"
        else
            echo \" Session: \$SESSION | Pane: \$PANE | [\$((IDX + 1))/\$COUNT] \"
        fi
    " \
    --bind "left:execute-silent(
        STATE=\$(cat $PANE_STATE_FILE)
        CURRENT_IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        NEW_IDX=\$((CURRENT_IDX - 1))
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)
        echo \"\$SESSION|\$PANE|\$NEW_IDX|\$COUNT\" > $PANE_STATE_FILE
    )+refresh-preview+transform-preview-label:
        STATE=\$(cat $PANE_STATE_FILE 2>/dev/null)
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)

        # 確保索引在範圍內（循環）
        if [ \"\$COUNT\" -gt 0 ]; then
            IDX=\$((IDX % COUNT))
            if [ \$IDX -lt 0 ]; then
                IDX=\$((COUNT + IDX))
            fi
        fi

        echo \" Session: \$SESSION | Pane: \$PANE | [\$((IDX + 1))/\$COUNT] \"
    " \
    --bind "right:execute-silent(
        STATE=\$(cat $PANE_STATE_FILE)
        CURRENT_IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        NEW_IDX=\$((CURRENT_IDX + 1))
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)
        echo \"\$SESSION|\$PANE|\$NEW_IDX|\$COUNT\" > $PANE_STATE_FILE
    )+refresh-preview+transform-preview-label:
        STATE=\$(cat $PANE_STATE_FILE 2>/dev/null)
        SESSION=\$(echo \"\$STATE\" | cut -d'|' -f1)
        PANE=\$(echo \"\$STATE\" | cut -d'|' -f2)
        IDX=\$(echo \"\$STATE\" | cut -d'|' -f3)
        COUNT=\$(echo \"\$STATE\" | cut -d'|' -f4)

        # 確保索引在範圍內（循環）
        if [ \"\$COUNT\" -gt 0 ]; then
            IDX=\$((IDX % COUNT))
            if [ \$IDX -lt 0 ]; then
                IDX=\$((COUNT + IDX))
            fi
        fi

        echo \" Session: \$SESSION | Pane: \$PANE | [\$((IDX + 1))/\$COUNT] \"
    " \
    --bind "ctrl-t:execute(
        NEW_SESSION=\$(gum input --placeholder 'New session name')
        if [ -n \"\$NEW_SESSION\" ]; then
            tmux new-session -d -s \"\$NEW_SESSION\" 2>/dev/null
            if [ \$? -eq 0 ]; then
                echo \"\$NEW_SESSION\" > $NEW_SESSION_FILE
            else
                gum style --foreground 196 'Failed to create session (may already exist)'
                sleep 2
            fi
        fi
    )+abort" \
    --preview-window=right:70%:nowrap 
)

# 3. 輸出結果
# 檢查是否創建了新的 session
if [ -f "$NEW_SESSION_FILE" ]; then
  NEW_SESSION=$(cat "$NEW_SESSION_FILE")
  if [ -n "$NEW_SESSION" ]; then
    echo "$NEW_SESSION"
  fi
elif [ -n "$SELECTED_SESSION" ]; then
  echo "$SELECTED_SESSION"
fi
