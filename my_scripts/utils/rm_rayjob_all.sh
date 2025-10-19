#!/bin/bash
# A robust script to stop and then delete all Ray jobs on the connected cluster.
# It uses grep and sed to handle inconsistent text formatting.

echo "Fetching list of all job and submission IDs..."

# This command extracts either a submission_id or a job_id from each line.
ALL_IDS=$(ray job list | grep -o -E "submission_id='[^']*'|job_id='[^']*'" | sed -E "s/submission_id='|job_id='//; s/'$//")

if [ -z "$ALL_IDS" ]; then
  echo "No Ray jobs found."
  exit 0
fi

echo "Found the following jobs to process:"
echo "$ALL_IDS"
echo "---"

# Loop through each ID
for JOB_ID in $ALL_IDS
do
  # Skip any 'None' values that might appear for jobs without IDs
  if [ "$JOB_ID" == "None" ]; then
    continue
  fi

  echo "Processing job/submission: $JOB_ID"

  # Attempt to stop the job. This will only work for RUNNING jobs.
  echo "  - Attempting to stop..."
  ray job stop "$JOB_ID" || true

  # Attempt to delete the job. This works on jobs in a terminal state.
  echo "  - Attempting to delete..."
  ray job delete "$JOB_ID" || true

  echo "  - Done."
done

echo "---"
echo "All jobs processed."
