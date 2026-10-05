CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)

CHARGE_NOW=$(cat /sys/class/power_supply/BAT1/charge_now)
CURRENT_NOW=$(cat /sys/class/power_supply/BAT1/current_now)

TOTAL_TIME_LEFT=$((CHARGE_NOW * 60 / CURRENT_NOW))

STATE_PATH="$HOME/.config/waybar/scripts/state/battery-time.txt"
SAMPLE_COUNT=120 # Should have this number on line 1, as metadata, so if they dont match the file is rewritten to match the new sample count

FIRST_SAMPLE_LINE=2
LAST_SAMPLE_LINE=$((SAMPLE_COUNT + 2))

# Create new file if doesn't exist
if [ ! -f "$STATE_PATH" ]; then
  echo "test"
  echo "2" >"$STATE_PATH"
  for ((i = FIRST_SAMPLE_LINE; i < LAST_SAMPLE_LINE; i++)); do
    echo "" >>"$STATE_PATH"
  done
fi

# Write current time at index
INDEX=$(head -n 1 "$STATE_PATH")
sed -i "$INDEX"s/.*/"$TOTAL_TIME_LEFT"/ "$STATE_PATH"

# Update index
if [ "$INDEX" -eq "$LAST_SAMPLE_LINE" ]; then
  INDEX=$FIRST_SAMPLE_LINE
else
  INDEX=$((INDEX + 1))
fi
sed -i 1s/.*/"$INDEX"/ "$STATE_PATH"

# Get average
LINE=0
SUM=0
COUNT=0
while read -r NUM; do
  LINE=$((LINE + 1))
  if [ "$LINE" = 1 ] || [ "$NUM" == "" ]; then
    continue
  fi
  SUM=$((SUM + NUM))
  COUNT=$((COUNT + 1))
done <"$STATE_PATH"

AVG=$((SUM / COUNT))

# Get hours/minutes
MINUTES_LEFT=$((AVG % 60))
HOURS_LEFT=$(((AVG - MINUTES_LEFT) / 60))

if [ "$MINUTES_LEFT" -lt 10 ]; then
  MINUTES_LEFT="0$MINUTES_LEFT"
fi

# Format for waybar
TIME_TILL_FULLY_CHARGED=$(printf "%sh %sm" "$HOURS_LEFT" "$MINUTES_LEFT")
BATTERY_INFO="$CAPACITY%"

BATTERY_INFO="$BATTERY_INFO ($TIME_TILL_FULLY_CHARGED)"
# echo "{\"text\": \"$BATTERY_INFO\", \"percentage\": $CAPACITY }"
echo "{ \"text\": \"$TIME_TILL_FULLY_CHARGED\" }"
